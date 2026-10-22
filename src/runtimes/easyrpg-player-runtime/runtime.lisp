(in-package #:game-launcher)

(defclass easyrpg-player-launcher (launcher)
  ())

(defun make-easyrpg-player-launcher (&key name profile exec phases)
	(make-instance 'easyrpg-player-launcher
		       :name name
		       :profile profile
		       :exec exec
		       :phases phases))

(defun easyrpg-player-exec-phase (ctx)
  (let ((proc
	 (sb-ext:run-program
	  "easyrpg-player"
	  (list (getf ctx :exec))
	  :environment (getf ctx :env)
	  :directory (pathname-directory-pathname (getf ctx :exec))
	  :search t
	  :output (or (getf ctx :log-path) *standard-output*)
	  :wait t)))
    (setf (getf ctx :process) proc)
    ctx))

(defparameter *easyrpg-player-pipeline*
	      '((exec . easyrpg-player-exec-phase)
		(teardown . teardown-processes)))

(defmethod launch ((l easyrpg-player-launcher))
	   (run-pipeline
	    (apply-phase-clauses *easyrpg-player-pipeline*
				 (launcher-phases l))
	    (standard-ctx l)))

(define-launcher-runtime
  easyrpg-player
  easyrpg-player-launcher
  make-easyrpg-player-launcher)
