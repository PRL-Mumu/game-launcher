(in-package #:game-launcher)

;;; A pipeline is an ordered alist: ((name . fn-or-nil) ...)
;;; nil fn = anchor only (skipped at compile time).

(defparameter *default-launch-pipeline*
  '((pre  . nil)
    (exec . nil)
    (post . nil)))

;;; --- list manipulation ------------------------------------------

(defun insert-phase (pipeline anchor name fn &key after)
  "Return a new pipeline with (NAME . FN) inserted before or after ANCHOR."
  (let ((pos (or (position anchor pipeline :key #'car)
                 (error "insert-phase: no anchor named ~a" anchor))))
    (when (assoc name pipeline)
      (error "insert-phase: phase ~a already exists" name))
    (append (subseq pipeline 0 (+ pos (if after 1 0)))
            (list (cons name fn))
            (subseq pipeline (+ pos (if after 1 0))))))

(defun replace-phase (pipeline name fn)
  "Return a new pipeline with NAME's function replaced by FN."
  (unless (assoc name pipeline)
    (error "replace-phase: no phase named ~a" name))
  (mapcar (lambda (p) (if (eq (car p) name) (cons name fn) p)) pipeline))

(defun remove-phase (pipeline name)
  "Return a new pipeline with NAME removed."
  (remove name pipeline :key #'car))

;;; --- clause application (for profile :phases) -------------------

(defun apply-phase-clause (pipeline clause)
  "Apply one profile clause to PIPELINE. Returns a new pipeline."
  (destructuring-bind (op &rest args) clause
    (ecase op
      (add-before (destructuring-bind (anchor name fn) args
		    (insert-phase pipeline anchor name
				  (coerce-phase-fn fn))))
      (add-after  (destructuring-bind (anchor name fn) args
		    (insert-phase pipeline anchor name
				  (coerce-phase-fn fn) :after t)))
      (replace    (destructuring-bind (name fn) args
		    (replace-phase pipeline name (coerce-phase-fn fn))))
      (delete     (destructuring-bind (name) args
		    (remove-phase pipeline name))))))

(defun coerce-phase-fn (spec)
  (etypecase spec
    (function spec)
    (symbol   (symbol-function spec))
    (cons     (compile-phase-form spec))))

(defun compile-phase-form (form)
  (let ((*package* (find-package :game-launcher))
        (*read-eval* nil))
    (compile nil `(lambda (ctx)
                    ,form
                    ctx))))

(defun apply-phase-clauses (base clauses)
  "Return BASE (a phase alist) with CLAUSES applied."
  (let ((phases (copy-alist base)))
    (dolist (clause clauses phases)
      (setf phases (apply-phase-clause phases clause)))))


(defun print-pipeline (pipeline &optional (stream *standard-output*))
  "Print PIPELINE as an ordered list, marking anchors."
  (format stream "~&Pipeline (~d entries):~%" (length pipeline))
  (loop for (name . fn) in pipeline
        for i from 0
        do (format stream "  ~2d. ~a ~:[(anchor)~;~:*-> ~a~]~%"
                   i name fn)))

(defgeneric resolve-launcher-log (launcher))
(defgeneric resolve-launcher-log-path (launcher))

(defmethod resolve-launcher-log ((l launcher))
  "Open a FRESH session log for this launch. Each launch gets its own
   uniquely named file (time + random suffix), so game output never
   accumulates into one shared, ever-growing file. A `current-` symlink
   pointing at it is maintained so RPC/LOG can find the live log from any
   image. Override this generic to plug in your own logging."
  (let* ((file (merge-pathnames
                (format nil "game-launcher/~(~A~)-~D-~D.log"
                        (launcher-runtime l)
                        (get-universal-time)
                        (random 1000000000))
                (uiop:xdg-data-home))))
    (ensure-directories-exist file)
    (update-current-log-symlink l file)
    (open file
          :direction :output
          :if-exists :append
          :if-does-not-exist :create
          :external-format :utf-8)))

(defun update-current-log-symlink (launcher file)
  "Point the `current-` symlink for LAUNCHER at the freshly created
   session FILE (atomically, via ln -sf). Any process can later resolve
   the same path through RESOLVE-LAUNCHER-LOG-PATH. Corrupt or absent
   targets are dropped silently: a missing game simply has no log."
  (let ((link (current-log-symlink launcher)))
    (ignore-errors
      (uiop:run-program
       (list "ln" "-sf" (namestring file) (namestring link))
       :error-output nil))))

(defun current-log-symlink (launcher)
  (merge-pathnames
   (format nil "game-launcher/current-~(~A~)-~A.log"
           (launcher-runtime launcher)
           (sanitize-filename (launcher-name launcher)))
   (uiop:xdg-data-home)))

(defmethod resolve-launcher-log-path ((l launcher))
  "Path of the session log for L, or NIL when L has never been
   launched. Resolves the `current-` symlink maintained at launch time,
   so it works even for games launched from a different image."
  (let ((link (current-log-symlink l)))
    (when (probe-file link)
      link)))

(defun sanitize-filename (name)
  "Make NAME safe as a filename component: drop/replace characters that are
   path separators or otherwise hostile, keep it deterministic."
  (with-output-to-string (out)
    (loop for ch across (princ-to-string name)
          do (cond
               ((or (alphanumericp ch) (find ch "-_ ."))
                (write-char ch out))
               (t
                (write-char #\- out))))))

(defmethod standard-ctx ((l launcher) &key (log t))
  (list :launcher l
		  :exec (launcher-exec l)
		  :env (build-environment (launcher-profile l))
		  :log-path (if log (resolve-launcher-log l) nil)
		  :process nil
		  :processes nil))

(defun run-command-async (ctx argv &key directory (wait nil) log-path)
  "Spawn ARGV in CTX's environment. If WAIT, block and check exit code.
   If LOG-PATH, redirect stdout/stderr there (append).
   Appends the process to (getf ctx :processes) when WAIT is NIL.
   Returns CTX."
  (let ((proc (if log-path
                  (sb-ext:run-program (first argv) (rest argv)
                                      :directory directory
                                      :environment (getf ctx :env)
                                      :search t
                                      :input nil
                                      :output log-path
                                      :error  log-path
                                      :if-output-exists :append
                                      :if-error-exists :append
                                      :wait wait)
                  (sb-ext:run-program (first argv) (rest argv)
                                      :directory directory
                                      :environment (getf ctx :env)
				      :output (getf ctx :log-path)
				      :error (getf ctx :log-path)
                                      :search t
                                      :input nil
                                      :wait wait))))
    (when (and wait (not (zerop (sb-ext:process-exit-code proc))))
      (error "command ~a exited with ~a" argv (sb-ext:process-exit-code proc)))
    (unless wait
      (setf (getf ctx :processes)
            (append (getf ctx :processes) (list proc))))
    ctx))

(defun split-shell-args (input)
  "split a command-line-style string into argv elements;
   double/single quotes group, whitespace outside quotes separates.
   A LIST of strings is returned unchanged (list args are already argv).
   NIL/empty string yields NIL."
  (typecase input
    (list input)
    (string (split-shell-args-string input))
    (t (error "split-shell-args: expected a string or list of strings, got ~S" input))))

(defun split-shell-args-string (string)
  (unless (null string)
  (let ((args '())
        (buf (make-array 0 :element-type 'character :fill-pointer 0 :adjustable t))
        (started nil)
        (quote nil))
    (flet ((flush ()
             (when started
               (push (copy-seq buf) args)
               (setf (fill-pointer buf) 0 started nil))))
      (loop for ch across string
            do (cond
                 ((and quote (char= ch quote))
                  (setf quote nil started t))
                 (quote
                  (vector-push-extend ch buf))
                 ((member ch '(#\" #\') :test #'char=)
                  (setf quote ch started t))
                 ((member ch '(#\space #\tab #\newline))
                  (flush))
                 (t
                  (vector-push-extend ch buf)
                  (setf started t))))
      (when quote (warn "unterminated quote in args: ~S" string))
      (flush))
    (nreverse args))))

(defun run-command (ctx argv &key log-path)
  "Spawn ARGV with ENV, wait for completion"
  (sb-ext:run-program (first argv) (rest argv)
		      :environment (getf ctx :env)
		      :output (or log-path (getf ctx :log-path))
		      :search t
		      :input nil
		      :wait t))

(defun teardown-processes (ctx)
  "Tear down each entry in ctx's :processes list. Entries are OS
   processes (from run-command-async) or (thread . stop) conses whose
   CDR is a function or a symbol naming one.  The :log-path stream, if
   any, is closed.  Clears the list even if an individual teardown fails."
  (when (getf ctx :log-path)
    (let ((log (getf ctx :log-path)))
      (when (streamp log) (ignore-errors (close log))))
    (setf (getf ctx :log-path) nil))
  (dolist (p (getf ctx :processes))
    (handler-case
        (cond
          ((consp p)                         ; (thread . stop)
           (let ((stop (cdr p)))
             (when stop
               (funcall (etypecase stop
                          (function stop)
                          (symbol (symbol-function stop))))))
           (sb-thread:join-thread (car p)))
          ((sb-ext:process-p p)              ; OS process
           (sb-ext:process-kill p 15)
           (unless (await-process-exit p 5)
             (ignore-errors (sb-ext:process-kill p 9))
             (unless (await-process-exit p 5)
               (warn "teardown-processes: process ~S did not exit after SIGKILL" p))))
          (t (warn "teardown-processes: unknown entry ~s" p)))
      (error (e)
        (warn "teardown-processes: failed on ~s: ~a" p e))))
  (setf (getf ctx :processes) nil)
  ctx)

(defun run-pipeline (phases ctx)
  (handler-case
      (dolist (phase phases ctx)
        (let ((fn (cdr phase)))
          (when fn (setf ctx (funcall fn ctx)))))
    (sb-sys:interactive-interrupt () ;; handle interactive interrupt
      (warn "Interrupted — tearing down ~d process(es)"
            (length (getf ctx :processes)))
      (teardown-processes ctx))
    (error (e) ;; handle error
      (warn "Pipeline Error: ~a" e)
      (warn "Interrupted — tearing down ~d process(es)"
            (length (getf ctx :processes)))
      (teardown-processes ctx))))

(defun note-process (ctx proc)
  (let ((l (getf ctx :launcher))
        lock)
    (when l
      (setf lock (ensure-lock l))
      (bt:with-lock-held (lock)
        (setf (launcher-process l) proc))))
  proc)

(defmacro define-standard-pipeline-launch (class pipeline)
  "usual way of defining pipeline launch unless you need to customize the ctx list"
  `(defmethod launch ((l ,class))
     (run-pipeline
      (apply-phase-clauses ,pipeline (launcher-phases l))
      (standard-ctx l))))
