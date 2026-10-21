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
                                      :output log-path
                                      :error  log-path
                                      :if-output-exists :append
                                      :if-error-exists :append
                                      :wait wait)
                  (sb-ext:run-program (first argv) (rest argv)
                                      :directory directory
                                      :environment (getf ctx :env)
                                      :search t
                                      :wait wait))))
    (when (and wait (not (zerop (sb-ext:process-exit-code proc))))
      (error "command ~a exited with ~a" argv (sb-ext:process-exit-code proc)))
    (unless wait
      (setf (getf ctx :processes)
            (append (getf ctx :processes) (list proc))))
    ctx))

(defun split-shell-args (string)
  "split a command-line-style string into argv elements;
   double/single quotes group, whitespace outside quotes separates"
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
    (nreverse args)))

(defun run-command (env argv)
  "Spawn ARGV with ENV, wait for completion"
  (sb-ext:run-program (first argv) (rest argv)
		      :environment env
		      :output *standard-output*
		      :search t
		      :wait t))

(defun teardown-processes (ctx)
  "Tear down each entry in ctx's :processes list. Entries are OS
   processes (from run-command-async) or (thread . stop) conses.
   Clears the list even if an individual teardown fails."
  (dolist (p (getf ctx :processes))
    (handler-case
        (cond
          ((and (consp p) (functionp (cdr p)))  ; (thread . stop)
           (funcall (cdr p))
           (sb-thread:join-thread (car p)))
          ((sb-ext:process-p p)                 ; OS process
           (sb-ext:process-kill p 15)
           (sb-ext:process-wait p))
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
    (sb-sys:interactive-interrupt ()
      (warn "Interrupted — tearing down ~d process(es)"
            (length (getf ctx :processes)))
      (teardown-processes ctx))))
