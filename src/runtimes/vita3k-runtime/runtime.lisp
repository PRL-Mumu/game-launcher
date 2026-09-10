(in-package #:game-launcher)

(defclass vita3k-launcher (launcher)
  ())

(defun make-vita3k-launcher (&key name profile exec)
  (let ((launcher
	  (make-instance 'vita3k-launcher
			 :name name
			 :profile profile
			 :exec exec)))
    launcher))

(defmethod launch ((launcher vita3k-launcher))
    (sb-ext:run-program
      "vita3k"
      (list "-r" (launcher-exec launcher))
      :environment (build-environment (launcher-profile launcher))
      :search t
      :output *standard-output*
      :wait nil))

(define-launcher-runtime
  vita3k
  vita3k-launcher
  make-vita3k-launcher)
