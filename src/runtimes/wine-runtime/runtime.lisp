(in-package #:game-launcher)

(defclass wine-launcher (launcher)
  ((args
    :initarg :args
    :accessor launcher-args)))

(defun make-wine-launcher (&key name profile exec args)
  (let ((launcher
          (make-instance 'wine-launcher
			 :name name
			 :profile profile
			 :exec exec
			 :args args)))
    launcher))

(defmethod launch ((launcher wine-launcher))
  (let* ((exe (pathname (launcher-exec launcher)))
         (dir (pathname-directory-pathname exe))
	 (log (open "/tmp/game-launcher.wine.log"
		    :direction :output
		    :if-exists :append
		    :if-does-not-exist :create)))
    (sb-ext:run-program
     "wine"
     (list (namestring exe))
     :directory dir
     :environment (build-environment (launcher-profile launcher))
     :search t
     :output log
     :error log
     :wait nil)))

(defmethod launcher->form ((launcher wine-launcher))
  (append
    `(,(launcher-runtime launcher)
       :name ,(launcher-name launcher))
    (when (profile-env (launcher-profile launcher))
    `(:profile ,(profile-env (launcher-profile launcher))))
    `(:exec ,(launcher-exec launcher))
    (when (launcher-args launcher)
      `(:args ,(launcher-args launcher)))))

(defmethod kill ((launcher wine-launcher))
  (sb-ext:run-program
    "wineserver"
    (list "-k")
    :environment (build-environment (launcher-profile launcher))
    :search t
    :output *standard-output*
    :wait t))

(defmethod launcher-end ((launcher wine-launcher))
  (format t "Thread ENDED ~%")
  (kill launcher)
  nil)


(defmethod launcher-runtime ((launcher wine-launcher))
  'wine)

(defmethod status ((launcher wine-launcher)
		   &optional (stream *standard-output*))
  (format stream "NAME: ~A~%" (launcher-name launcher))
  (format stream "ENV: ~A~%" (profile-env (launcher-profile launcher)))
  (format stream "EXEC: ~A~%" (launcher-exec launcher)))

(defparameter *wine-basic-profile*
  '(("DXVK_ASYNC" "1")
    ("WINE_LARGE_ADDRESS_AWARE" "0")))

(register-launcher
  'wine
  #'make-wine-launcher)
