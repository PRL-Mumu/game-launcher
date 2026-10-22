(in-package #:game-launcher)

(defclass executable-launcher (launcher)
  ((args      :initarg :args      :accessor launcher-args)))

(defun make-executable-launcher (&key name profile exec args phases)
  (make-instance 'executable-launcher
		 :name name
		 :profile profile
		 :exec exec
		 :args args
		 :phases phases))

(defun executable-exec-phase (ctx)
  (setf (getf ctx :process)
	(sb-ext:run-program
	 (getf ctx :exec)
	 (getf ctx :args)
	 :environment (getf ctx :env)
	 :directory (pathname-directory-pathname (getf ctx :exec))
	 :search t
	 :output (or (getf ctx :log-path) *standard-output*)
	 :wait t))
  ctx)

(defparameter *executable-launch-pipeline*
  '((pre  . nil)
    (exec . executable-exec-phase)
    (post . nil)
    (teardown . teardown-processes)))

(defmethod launch ((l executable-launcher))
  (run-pipeline
   (apply-phase-clauses *executable-launch-pipeline* (launcher-phases l))
   `(,@(standard-ctx l)
     :args ,(or (launcher-args l) '()))))

(defmethod launcher->form ((launcher executable-launcher))
  (append (call-next-method)
          (when (launcher-args launcher)
            `(:args ,(launcher-args launcher)))))

(define-launcher-runtime
    exec
  executable-launcher
  make-executable-launcher)
