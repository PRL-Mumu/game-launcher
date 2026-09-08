(in-package #:game-launcher)

(defclass proton-launcher (launcher)
  ((args
     :initarg :args
     :accessor launcher-args)
   (lutris-id
     :initarg :lutris-id
     :initform nil
     :accessor launcher-lutris-id)))

(defun make-proton-launcher (&key name profile exec args lutris-id)
  (let ((launcher
	  (make-instance 'proton-launcher
			 :name name
			 :profile profile
			 :exec exec
			 :args args
			 :lutris-id lutris-id)))
    launcher))

(defmethod launch ((launcher proton-launcher))
  (let* ((exe (pathname (launcher-exec launcher)))
	 (dir (pathname-directory-pathname exe)))
    (with-open-file (log "/tmp/game-launcher.wine.log"
			 :direction :output
			 :if-exists :append
			 :if-does-not-exist :create)
      (sb-ext:run-program
     "/home/rush/common-lisp/lutris-GE-Proton8-26-x86_64/bin/wine"
	(cons (namestring exe) (launcher-args launcher))
	:directory dir
	:environment (build-environment (launcher-profile launcher))
	:search t
	:output log
	:error log
	:wait nil))))

(defmethod launcher->form ((launcher proton-launcher))
  (append (call-next-method)
          (when (launcher-args launcher)
            `(:args ,(launcher-args launcher)))
          (when (launcher-lutris-id launcher)
            `(:lutris-id ,(launcher-lutris-id launcher)))))

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

(define-launcher-runtime proton proton-launcher make-proton-launcher)
