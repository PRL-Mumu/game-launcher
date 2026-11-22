(in-package #:game-launcher)

;; note vita3k launcher. needs emulator vita3k available in path as "vita3k"

(eval-when (:compile-toplevel :load-toplevel :execute)
  (use-package :game-launcher))

(defclass vita3k-launcher (launcher) ())

(defun vita3k-exec (ctx)
  ;(setf (getf ctx :process)) no need to set process
	(sb-ext:run-program
	 "vita3k"
	 (list "-r" (getf ctx :exec))
	 :environment (getf ctx :env)
	 :search t
				:input nil
	            :output (getf ctx :log-path)
	            :error (getf ctx :log-path)
	 :wait nil)  ;; dont wait for emulator
  ctx)

(defparameter *vita3k-pipeline*
  '((exec . vita3k-exec)))

(defmethod launch ((l vita3k-launcher))
  (run-pipeline
   (apply-phase-clauses *vita3k-pipeline* (launcher-phases l))
   (standard-ctx l :log nil)))

(define-launcher-runtime
  vita3k
  vita3k-launcher)
