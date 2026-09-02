(in-package #:game-launcher)

(defclass proton-launcher (launcher)
  ())

(defun make-proton-launcher (&key name profile exec)
  (let ((launcher
          (make-instance 'proton-launcher
			 :name name
			 :profile profile
			 :exec exec)))
    launcher))

(defmethod launch ((launcher proton-launcher))
  (let* ((exe (pathname (launcher-exec launcher)))
         (dir (pathname-directory-pathname exe))
	 (log (open "/tmp/game-launcher.wine.log"
		    :direction :output
		    :if-exists :append
		    :if-does-not-exist :create)))
    (sb-ext:run-program
     "/home/rush/common-lisp/lutris-GE-Proton8-26-x86_64/bin/wine"
     (list (namestring exe))
     :directory dir
     :environment (build-environment (launcher-profile launcher))
     :search t
     :output log
     :error log
     :wait nil)))

(defmethod launcher-end ((launcher proton-launcher))
  (format t "Thread ENDED ~%")
  (kill launcher)
  nil)

(defmethod kill ((launcher proton-launcher))

  (sb-ext:run-program
   "wineserver"
   (list "-k")
   :environment (build-environment (launcher-profile launcher))
   :search t
   :output *standard-output*
   :wait t))

(defmethod launcher-runtime ((launcher proton-launcher))
  'proton)

(defmethod status ((launcher proton-launcher)
                   &optional (stream *standard-output*))
  (format stream "NAME: ~A~%" (launcher-name launcher))
  (format stream "ENV: ~A~%" (profile-env (launcher-profile launcher)))
  (format stream "EXEC: ~A~%" (launcher-exec launcher)))


(register-launcher
 'proton
 #'make-proton-launcher)
