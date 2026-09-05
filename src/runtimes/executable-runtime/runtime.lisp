(in-package #:game-launcher)

(defclass executable-launcher (launcher)
  ((args
    :initarg :args
    :accessor launcher-args)))

(defun make-executable-launcher (&key name profile exec args)
  (let ((launcher
	  (make-instance 'executable-launcher
			 :name name
			 :profile profile
			 :exec exec
			 :args args)))
    launcher))

(defmethod launch ((launcher executable-launcher))
  (sb-ext:run-program
    (launcher-exec launcher)
    (if (launcher-args launcher)
      (launcher-args launcher)
      (quote ()))
    :environment (build-environment (launcher-profile launcher))
    :search t
    :output *standard-output*
    :wait nil))

(defmethod status ((launcher executable-launcher)
		   &optional (stream *standard-output*))
  (format stream "NAME: ~A~%" (launcher-name launcher))
  (format stream "ENV: ~A~%" (profile-env (launcher-profile launcher)))
  (format stream "EXEC: ~A~%" (launcher-exec launcher)))


(defmethod launcher->form ((launcher executable-launcher))
  (append
    `(,(launcher-runtime launcher)
       :name ,(launcher-name launcher))
    (when (profile-env (launcher-profile launcher))
      `(:profile ,(profile-env (launcher-profile launcher))))
    `(:exec ,(launcher-exec launcher))
    (when (launcher-args launcher)
      `(:args ,(launcher-args launcher)))))

(define-launcher-runtime exec executable-launcher make-executable-launcher)
