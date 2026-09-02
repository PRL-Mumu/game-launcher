(in-package #:game-launcher)

(defclass steam-launcher (launcher)
  ())

(defun make-steam-launcher (&key name profile exec)
  (let ((launcher
	  (make-instance 'steam-launcher
			 :name name
			 :profile profile
			 :exec exec)))
    launcher))

(defmethod launch ((launcher steam-launcher))
    (sb-ext:run-program
      "steam"
      (list (launcher-exec launcher))
      :environment (build-environment (launcher-profile launcher))
      :search t
      :output *standard-output*
      :wait nil))

(defmethod status ((launcher steam-launcher)
		   &optional (stream *standard-output*))
  (format stream "NAME: ~A~%" (launcher-name launcher))
  (format stream "ENV: ~A~%" (profile-env (launcher-profile launcher)))
  (format stream "EXEC: ~A~%" (launcher-exec launcher)))

(defmethod launcher-runtime ((launcher steam-launcher))
  'steam)

;; (defmethod launcher->form ((launcher steam-launcher))
;;   `(make-launcher
;;      ',(launcher-runtime launcher)
;;      :name ,(launcher-name launcher)
;;      :profile
;;      ,(let ((env (profile-env (launcher-profile launcher))))
;; 	`(env ,@env))
;;      :exec ,(launcher-exec launcher)))


(register-launcher
  'steam
  #'make-steam-launcher)
