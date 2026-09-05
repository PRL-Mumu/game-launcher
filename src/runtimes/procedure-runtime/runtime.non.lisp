(in-package #:game-launcher)

(defclass procedure-launcher ()
  ())

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

(defmacro


(define-launcher-runtime exec procedure-launcher make-procedure-launcher)

