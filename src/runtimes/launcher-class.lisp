(in-package #:game-launcher)

(defclass launcher ()
  ((name
    :initarg :name
    :accessor launcher-name)
   (profile
    :initarg :profile
    :accessor launcher-profile)
   (exec
    :initarg :exec
    :accessor launcher-exec)))

(defgeneric launcherp (obj))
(defmethod launcherp ((o launcher))
"Return T if o is a 'launcher' instance."
  t)
(defmethod launcherp ((o t))
  nil)

(defgeneric launcher-runtime (launcher))

(defgeneric launch (launcher))

(defgeneric status (launcher &optional stream))

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
    (profile-slot->form (launcher-profile launcher))
    (when (launcher-exec launcher)
      `(:exec ,(launcher-exec launcher)))))

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
  "Register a launcher runtime. If CONSTRUCTOR is omitted, generate
   a MAKE-<NAME>-LAUNCHER function that forwards to MAKE-LAUNCHER."
  (if constructor
      `(progn
         (defmethod launcher-runtime ((launcher ,class))
           ',name)
         (register-launcher ',name #',constructor))
      (let ((ctor (intern (format nil "MAKE-~A-LAUNCHER" name))))
        `(progn
           (defmethod launcher-runtime ((launcher ,class))
             ',name)
           (defun ,ctor (&rest args)
             (apply #'make-launcher :runtime ',name args))
           (register-launcher ',name #',ctor)))))


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
  (labels ((lookup () (gethash runtime-symbol *runtime-index*)))
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
