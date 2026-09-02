(in-package #:game-launcher)


(defclass rpgmaker-linux-launcher (launcher)
  ())

(defun make-rpgmaker-linux-launcher (&key name profile exec)
  (let ((launcher
	  (make-instance 'rpgmaker-linux-launcher
			 :name name
			 :profile profile
			 :exec exec)))
    launcher))

(defmethod launch ((launcher rpgmaker-linux-launcher))
  (let* ((exe (pathname (launcher-exec launcher)))
	 (dir (pathname-directory-pathname exe)))
    (sb-ext:run-program
      "rpgmaker-linux"
      (list (namestring exe))
      :directory dir
      :environment (build-environment (launcher-profile launcher))
      :search t
      :output *standard-output*
      :wait nil)))

(defmethod launcher-runtime ((launcher rpgmaker-linux-launcher))
  'rpgmaker)

(register-launcher
  'rpgmaker
  #'make-rpgmaker-linux-launcher)
