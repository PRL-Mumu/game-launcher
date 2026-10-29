(in-package #:game-launcher)


(defclass rpgmaker-linux-launcher (launcher)
  ())

(defun make-rpgmaker-linux-launcher (&key name profile exec phases tags)
  "Create a launcher: an executable-launcher on Windows, an
rpgmaker-linux-launcher on Unix."
  (cond
   ((uiop:os-windows-p)
    (make-instance 'executable-launcher
		   :name name
		   :profile profile
		   :exec exec
		   :phases phases
		   :tags tags))
   ((uiop:os-unix-p)
    (make-instance 'rpgmaker-linux-launcher
                   :name name
                   :profile profile
                   :exec exec
		   :phases phases
		   :tags tags))))

(defun rpgmaker-linux-exec-phase (ctx)
  (let ((proc
	 (sb-ext:run-program
	  "rpgmaker-linux"
	  (list (getf ctx :exec))
	  :environment (getf ctx :env)
	  :directory (pathname-directory-pathname (getf ctx :exec))
	  :search t
	  :output (or (getf ctx :log-path) *standard-output*)
	  :wait t)))
    (setf (getf ctx :process) proc)
    ctx))

(defparameter *rpgmaker-linux-pipeline*
	      '((exec . rpgmaker-linux-exec-phase)
		(teardown . teardown-processes)))

(defmethod launch ((l rpgmaker-linux-launcher))
	   (run-pipeline
	    (apply-phase-clauses *rpgmaker-linux-pipeline*
				 (launcher-phases l))
	    (standard-ctx l)))

(define-launcher-runtime  ;; macro
 rpgmaker
 rpgmaker-linux-launcher
 make-rpgmaker-linux-launcher)
