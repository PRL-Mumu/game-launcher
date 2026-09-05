(in-package #:game-launcher)

(defclass easyrpg-player-launcher (launcher)
  ())

(defun make-easyrpg-player-launcher (&key name profile exec)
  (let ((launcher
	  (make-instance 'easyrpg-player-launcher
			 :name name
			 :profile profile
			 :exec exec)))
    launcher))

(defmethod launch ((launcher easyrpg-player-launcher))
    (sb-ext:run-program
      "easyrpg-player"
      (list ".")
      :directory (uiop:pathname-directory-pathname (pathname (launcher-exec launcher)))
      :environment (build-environment (launcher-profile launcher))
      :search t
      :output *standard-output*
      :wait nil))

(defmethod status ((launcher easyrpg-player-launcher)
		   &optional (stream *standard-output*))
  (format stream "NAME: ~A~%" (launcher-name launcher))
  (format stream "ENV: ~A~%" (profile-env (launcher-profile launcher)))
  (format stream "EXEC: ~A~%" (launcher-exec launcher)))

(define-launcher-runtime easyrpg-player easyrpg-player-launcher make-easyrpg-player-launcher)
