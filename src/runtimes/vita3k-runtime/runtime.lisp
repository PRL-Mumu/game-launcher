(in-package #:game-launcher)

(defclass vita3k-launcher (launcher)
  ())

(defun make-vita3k-launcher (&key name profile exec phases)
  (make-instance 'vita3k-launcher
		 :name name
		 :profile profile
		 :exec exec
		 :phases phases))

(defun vite3k-exec (ctx)
  (setf (getf ctx :process)
	(sb-ext:run-program
	 "vita3k"
	 (list "-r" (getf ctx :exec))
	 :environment (getf ctx :env)
	 :search t
	 :wait nil))  ;; dont wait for emulator
  ctx)

(defparameter *vita3k-pipeline*
  '((exec . vita3k-exec)))

(defmethod launch ((l vita3k-launcher))
  (run-pipeline
   (apply-phase-clauses *vita3k-pipeline* (launcher-phases l))
   (standard-ctx l)))

(define-launcher-runtime
  vita3k
  vita3k-launcher
  make-vita3k-launcher)
