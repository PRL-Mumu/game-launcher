(in-package #:game-launcher)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (use-package :game-launcher))

(defclass steam-launcher (launcher)
  ())

(defun steam-exec (ctx)
  (setf (getf ctx :process)
	(sb-ext:run-program
	 "steam"
	 (list (getf ctx :exec))
	 :environment (getf ctx :env)
	 :search t
	 :wait nil)) ;; dont wait for steam
  ctx)

(defparameter *steam-pipeline*
  '((exec . steam-exec)))

(defmethod launch ((l steam-launcher))
  (run-pipeline
   (apply-phase-clauses *steam-pipeline* (launcher-phases l))
   (standard-ctx l :log nil))) ;; logging is set to nil so log file wont be created


(define-launcher-runtime
  steam ;; symbol
  steam-launcher ;; class
  )
