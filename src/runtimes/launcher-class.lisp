(in-package #:game-launcher)

(defclass launcher ()
  ((name    :initarg :name    :accessor launcher-name)
   (exec    :initarg :exec    :accessor launcher-exec)
   (profile :initarg :profile :accessor launcher-profile)  ; env data
   (phases  :initarg :phases  :accessor launcher-phases)   ; clause list
   (tags    :initarg :tags    :initform nil   :accessor launcher-tags)
   (process :initarg :process :initform nil   :accessor launcher-process) ; main process
   (lock    :initarg :lock    :initform nil   :accessor launcher-lock))) ; running process

(defgeneric launcherp (obj))
(defmethod launcherp ((o launcher))
  "Return T if o is a 'launcher' instance."
  t)
(defmethod launcherp ((o t))
  nil)

(defgeneric launcher-runtime (launcher))

(defgeneric launch (launcher))

(defmethod ensure-lock ((l launcher))
  (or (launcher-lock l)
      (setf (slot-value l 'lock) (bt:make-lock "launcher-process"))))

(defgeneric stop-launcher (launcher &key &allow-other-keys)
  (:documentation "Stop the OS process attached to LAUNCHER.
Returns two values: LAUNCHER and a plist of (:pid :name) for the stopped
process, or NIL if nothing was stopped."))

(defmethod stop-launcher ((l launcher) &key (timeout 10) (force t))
  (let ((lock (ensure-lock l)))
    (bt:with-lock-held (lock)
      (let ((proc (launcher-process l)))
        (when (and proc (sb-ext:process-p proc)
                   (eq (sb-ext:process-status proc) :running))
          (let* ((pid (sb-ext:process-pid proc))
                 (name (format nil "~A (~D)" (launcher-name l) pid)))
            (sb-ext:process-kill proc 15)
            (unless (await-process-exit proc timeout)
              (when force
                (sb-ext:process-kill proc 9)
                ;; also reap any child processes (wine/easyrpg spawn children)
                (ignore-errors
                  (sb-ext:run-program "pkill" (list "-9" "-P" (format nil "~D" pid)) :wait nil))))
            (setf (launcher-process l) nil)
            (values l (list :pid pid :name name)))))
      ;  (values l nil)
      )))

(defun await-process-exit (proc timeout &key (poll 0.1))
  (let ((deadline (+ (get-universal-time) (ceiling timeout))))
    (loop
      (unless (eq (sb-ext:process-status proc) :running)
        (return t))
      (when (>= (get-universal-time) deadline)
        (return nil))
      (sleep poll))))

(defun launcher-running-p (l)
  "Return T if LAUNCHER currently has a running OS process attached."
  (let ((proc (launcher-process l)))
    (and proc (sb-ext:process-p proc)
         (eq (sb-ext:process-status proc) :running))))

(defgeneric status (launcher &optional stream))

(defgeneric launcher-args (launcher)
	    (:method ((launcher launcher)) nil))

(defgeneric profile-slot->form (p)
	    (:documentation "Convert a profile slot to a form representation. Takes a profile object and returns a list containing the keyword :profile and either the name or environment of the profile."))

(defmethod profile-slot->form ((p profile))
  (cond ((profile-name p) (list :profile (profile-name p)))
	((profile-env p)  (list :profile (profile-env p)))))

(defgeneric launcher->form (launcher)
	    (:documentation "Convert a launcher object into its form representation."))

(defmethod launcher->form ((launcher launcher))
  (append
    `(,(launcher-runtime launcher)
       :name ,(launcher-name launcher))
    (when (launcher-exec launcher) ;; check when
      `(:exec ,(launcher-exec launcher)))
    (when (launcher-phases launcher)
      `(:phases ,(launcher-phases launcher)))
    (when (launcher-tags launcher)
      `(:tags ,(launcher-tags launcher)))
    (profile-slot->form (launcher-profile launcher))))

(defmethod launcher-end ((launcher launcher))
  "Terminate the launcher. Default implementation does nothing.
  This method can be overridden by subclasses to perform cleanup."
  nil)

(defvar *runtime-index* (make-hash-table :test 'eq))

(defvar *loaded-runtime-files* (make-hash-table :test 'equal))

(defun runtime-path ()
  (merge-pathnames "src/runtimes/"
		   (asdf:system-source-directory :game-launcher)))


(defmacro define-launcher-runtime (name class &optional constructor)
  (let ((class-obj (find-class class)))
    (unless (c2mop:class-finalized-p class-obj)
      (c2mop:finalize-inheritance class-obj))
    `(progn
       (defmethod launcher-runtime ((l ,class)) ',name)
       ,(if constructor
            `(register-launcher ',name #',constructor)
            (let* ((ctor  (intern (format nil "MAKE-~A-LAUNCHER" name)
                                  (symbol-package name)))
                   (pairs (loop for slot in (c2mop:class-slots class-obj)
                                for ias  = (c2mop:slot-definition-initargs slot)
                                when ias append (loop for ia in ias
                                                      collect (cons ia (intern (symbol-name ia)
                                                                               (symbol-package name)))))))
              `(progn
                 (defun ,ctor (&key ,@(mapcar #'cdr pairs))
                   (make-instance ',class
                                  ,@(loop for (ia . var) in pairs
                                          append (list ia var))))
                 (register-launcher ',name #',ctor)))))))

(defun runtime-file-provides (file)
  "Read FILE without evaluating it, collecting runtime symbols
  declared by DEFINE-LAUNCHER-RUNTIME forms."
  (let ((*read-eval* nil)
	(*package* *package*)
	(provides '()))
    (with-open-file (in file)
      (handler-case
	  (loop
	    (let ((form (read in)))
	      ;; Track IN-PACKAGE while reading the file.
	      (when (and (consp form)
			 (eq (first form) 'in-package)
			 (consp (rest form)))
		(let* ((name (second form))
		       (pkg (typecase name
			      (symbol (find-package (symbol-name name)))
			      (string (find-package name)))))
		  (when pkg
		    (setf *package* pkg))))

	      ;; Find DEFINE-LAUNCHER-RUNTIME declarations.
	      (when (and (consp form)
			 (symbolp (first form))
			 (string= (symbol-name (first form))
				  "DEFINE-LAUNCHER-RUNTIME")
			 (consp (rest form)))
		(let ((name (second form)))
		  (when (symbolp name)
		    (push name provides))))))
	(end-of-file ())
	(reader-error (e)
	  (warn "Read error while scanning ~A: ~A" file e))))
    (nreverse provides)))

(defun index-runtimes (dir)
  "Scan DIR's subdirectories and map each runtime symbol to its
  runtime.lisp.  Cheap: nothing is evaluated."
  (clrhash *runtime-index*)
  (dolist (subdir (uiop:subdirectories dir))
    (let ((entry (merge-pathnames "runtime.lisp" subdir)))
      (when (probe-file entry)
	(dolist (sym (runtime-file-provides entry))
	  (setf (gethash sym *runtime-index*) entry))))))

(defun load-runtime-file (file)
					; (format t "Loading runtime: ~A~%" file)
  (handler-case (load file)
    (error (e)
      (error "Failed loading ~A: ~A" file e)))
  (setf (gethash file *loaded-runtime-files*) t)
  file)

(defun load-runtime (dir runtime-symbol)
  "Ensure the runtime file that registers RUNTIME-SYMBOL under DIR is
  loaded.  Re-scans DIR once on a miss, so runtimes added after startup
  are still found.  Returns the pathname, or NIL if no such runtime."
  (labels ((lookup ()
	     (or (gethash runtime-symbol *runtime-index*)
		 (loop for sym being the hash-keys of *runtime-index*
			 using (hash-value file)
		       when (string-equal (symbol-name sym) (symbol-name runtime-symbol))
			 return file))))
    (let ((file (or (lookup) (progn (index-runtimes dir) (lookup)))))
      (when file
	(unless (gethash file *loaded-runtime-files*)
	  (load-runtime-file file))
	file))))

(defun known-runtimes (dir)
  "All runtime symbols present under DIR, without loading anything.
  Use this for listing instead of the registry."
  (index-runtimes dir)
  (loop for sym being the hash-keys of *runtime-index* collect sym))

(defun reload-runtime (dir runtime-symbol)
  "Force a re-load (e.g. after editing the runtime file)."
  (let ((file (gethash runtime-symbol *runtime-index*)))
    (when file (remhash file *loaded-runtime-files*)))
  (load-runtime dir runtime-symbol))

(defun rush-debug-load-runtimes ()
  ;; Reload all known runtimes for debugging purposes.
  (loop :for i :in (known-runtimes (runtime-path))
	:do (reload-runtime (runtime-path) i)))

(defun load-runtimes (dir)
  (index-runtimes dir))

(define-condition unknown-runtime (error)
  ((runtime :initarg :runtime :reader unknown-runtime-name))
  (:report (lambda (c s)
	     (format s "Unknown launcher runtime: ~A"
		     (unknown-runtime-name c)))))

(defun export-runtime-symbol-into-core (&rest symbols)
  "Make SYMBOLS external in :game-launcher, importing them if needed."
  (dolist (sym symbols)
    (import sym :game-launcher)
    (export sym :game-launcher)))

(defmacro when-packages ((&rest packages) &body body)
  `(when (every #'find-package (list ,@packages))
     ,@body))

(defun make-launcher (runtime &rest args)
  (load-runtime (runtime-path) runtime)
  (multiple-value-bind (clean-args marker) (split-profile-marker args)
    (let ((constructor (gethash runtime *launcher-constructors*)))
      (if constructor
	  (progn
	    (setf (getf clean-args :profile)
		  (if marker
		      (ensure-profile (marker->name marker)
				      (getf clean-args :profile))
		      (resolve-profile (getf clean-args :profile))))
	    (apply constructor clean-args))
	  (restart-case
	      (error 'unknown-runtime :runtime runtime)
	    (continue ()
	      :report (lambda (s)
			(format s "Skip this launcher (~A)" runtime))
	      nil))))))
