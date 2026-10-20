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
  (let ((proc
	  (sb-ext:run-program
	   (getf ctx :exec)
	   (getf ctx :args)
	   :environment (getf ctx :env)
	   :directory (pathname-directory-pathname (getf ctx :exec))
	   :search t
	   :output *standard-output*
	   :wait t)))
    (setf (getf ctx :process) proc)
    ctx))

(defparameter *executable-launch-pipeline*
  '((pre  . nil)
    (exec . executable-exec-phase)
    (post . nil)
    (teardown . teardown-processes)))

(defmethod launch ((l executable-launcher))
  (run-pipeline
   (apply-phase-clauses *executable-launch-pipeline*
                        (launcher-phases l))
   (list :launcher l
         :exec     (launcher-exec l)
         :args     (or (launcher-args l) '())
         :env      (build-environment (launcher-profile l))
         :process  nil
	 :processes nil) ;; ctx to pass around
   ))

(defmethod status ((launcher executable-launcher)
		   &optional (stream *standard-output*))
  (format stream "NAME: ~A~%" (launcher-name launcher))
  (format stream "ENV: ~A~%" (profile-env (launcher-profile launcher)))
  (format stream "EXEC: ~A~%" (launcher-exec launcher)))

(defmethod launcher->form ((launcher executable-launcher))
  (append (call-next-method)
          (when (launcher-args launcher)
            `(:args ,(launcher-args launcher)))
	  (when (launcher-phases launcher)
	    `(:phases ,(launcher-phases launcher)))))

(define-launcher-runtime
    exec
  executable-launcher
  make-executable-launcher)
