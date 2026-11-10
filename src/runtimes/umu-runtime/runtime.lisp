(in-package #:game-launcher)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (use-package :game-launcher))

(defclass umu-launcher (launcher)
  ((args
     :initarg :args
     :accessor launcher-args)
   (lutris-id
     :initarg :lutris-id
     :initform nil
     :accessor launcher-lutris-id)))

(defmethod generate-umu-env ((l umu-launcher))
  "WIP umu-env generator"
  (make-profile `(("GAMEID" ,(launcher-name l))
		  ("PROTONPATH" "GE-Proton"); change geproton to data defined
		  ("UMU_RUNTIME_UPDATE" "0"); change to a check
		  )))

(defun umu-exec-phase (ctx)
  (let ((proc (sb-ext:run-program
                "umu-run"
                (cons (getf ctx :exec) (getf ctx :args))
                :environment (getf ctx :env)
                :directory (pathname-directory-pathname (getf ctx :exec))
                :search t
                :output (or (getf ctx :log-path) *standard-output*)
                :wait nil)))
    (note-process ctx proc)
    (sb-ext:process-wait proc)
    ctx))

(defparameter *umu-launch-pipeline*
  '((pre  . nil)
    (exec . umu-exec-phase)
    (post . nil)
    (teardown . teardown-processes)))

(defmethod launch ((l umu-launcher))
  (run-pipeline
    (apply-phase-clauses *umu-launch-pipeline* (launcher-phases l))
    (list :launcher l
	  :exec (launcher-exec l)
	  :env (build-environment (generate-umu-env l) (launcher-profile l))
	  :log-path (resolve-launcher-log l)
	  :process nil
	  :processes nil)))

(defmethod launcher->form ((launcher umu-launcher))
  (append (call-next-method)
	  (when (launcher-args launcher)
	    `(:args ,(launcher-args launcher)))
	  (when (launcher-lutris-id launcher)
	    `(:lutris-id ,(launcher-lutris-id launcher)))))

(define-launcher-runtime umu umu-launcher)
