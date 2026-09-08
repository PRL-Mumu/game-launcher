(in-package #:game-launcher)

(defclass wine-launcher (launcher)
  ((args
     :initarg :args
     :accessor launcher-args)
   (lutris-id
     :initarg :lutris-id
     :initform nil
     :accessor launcher-lutris-id)))

(defun make-wine-launcher (&key name profile exec args lutris-id)
  (let ((launcher
	  (make-instance 'wine-launcher
			 :name name
			 :profile profile
			 :exec exec
			 :args args
			 :lutris-id lutris-id)))
    launcher))

(defmethod launch ((launcher wine-launcher))
  (let* ((exe (pathname (launcher-exec launcher)))
	 (dir (pathname-directory-pathname exe)))
    (with-open-file (log "/tmp/game-launcher.wine.log"
			 :direction :output
			 :if-exists :append
			 :if-does-not-exist :create)
      (sb-ext:run-program
	"wine"
	(cons (namestring exe) (launcher-args launcher))
	:directory dir
	:environment (build-environment (launcher-profile launcher))
	:search t
	:output log
	:error log
	:wait nil))))


(defmethod launcher->form ((launcher wine-launcher))
  (append (call-next-method)
          (when (launcher-args launcher)
            `(:args ,(launcher-args launcher)))
          (when (launcher-lutris-id launcher)
            `(:lutris-id ,(launcher-lutris-id launcher)))))

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

(defmethod status ((launcher wine-launcher)
		   &optional (stream *standard-output*))
  (format stream "NAME: ~A~%" (launcher-name launcher))
  (format stream "ENV: ~A~%" (profile-env (launcher-profile launcher)))
  (format stream "EXEC: ~A~%" (launcher-exec launcher))
  (format stream "ARGS ~A~%" (launcher-args launcher)))

(defparameter *wine-basic-profile*
  '(("DXVK_ASYNC" "1")
    ("WINE_LARGE_ADDRESS_AWARE" "0")))

(define-launcher-runtime
  wine
  wine-launcher
  make-wine-launcher)
