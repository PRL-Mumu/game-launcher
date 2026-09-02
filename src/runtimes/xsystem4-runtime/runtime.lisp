(in-package #:game-launcher)

(defclass xsystem4-launcher (launcher)
  ())

(defun make-xsystem4-launcher (&key name profile exec)
  (let ((launcher
	  (make-instance 'xsystem4-launcher
			 :name name
			 :profile profile
			 :exec exec)))
    launcher))

(defmethod launch ((launcher xsystem4-launcher))
    (sb-ext:run-program
      "xsystem4"
      (list ".")
      :directory (pathname-directory-pathname (pathname (launcher-exec launcher)))
      :environment (build-environment (launcher-profile launcher))
      :search t
      :output *standard-output*
      :wait nil))

(defmethod status ((launcher xsystem4-launcher)
		   &optional (stream *standard-output*))
  (format stream "NAME: ~A~%" (launcher-name launcher))
  (format stream "ENV: ~A~%" (profile-env (launcher-profile launcher)))
  (format stream "EXEC: ~A~%" (launcher-exec launcher)))


(defmethod launcher-runtime ((launcher xsystem4-launcher))
  'xsystem4)

(register-launcher
  'xsystem4
  #'make-xsystem4-launcher)
