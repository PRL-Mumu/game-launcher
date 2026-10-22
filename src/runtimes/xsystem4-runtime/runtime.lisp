(in-package #:game-launcher)

(defclass xsystem4-launcher (launcher)
  ())

(defun make-xsystem4-launcher (&key name profile exec phases)
	  (make-instance 'xsystem4-launcher
			 :name name
			 :profile profile
			 :exec exec
			 :phases phases))

(defun xsystem4-exec (ctx)
  (setf (getf ctx :process)
	(sb-ext:run-program
	 "xsystem4"
	 (list (namestring (pathname-directory-pathname (getf ctx :exec))))
	 :environment (getf ctx :env)
	 :directory (pathname-directory-pathname (getf ctx :exec))
	 :search t
	 :output (or (getf ctx :log-path) *standard-output*)
	 :wait t))
  ctx)

(defparameter *xsystem4-launch-pipeline*
  '((pre  . nil)
    (exec . xsystem4-exec)
    (post . nil)
    (teardown . teardown-processes)))

(defmethod launch ((l xsystem4-launcher))
  (run-pipeline
   (apply-phase-clauses *xsystem4-launch-pipeline* (launcher-phases l))
   (standard-ctx l))
  (format t "exited"))

(define-launcher-runtime
  xsystem4
  xsystem4-launcher
  make-xsystem4-launcher)
