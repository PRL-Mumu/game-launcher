(in-package #:game-launcher)

(defclass wine-launcher (launcher)
  ( (args
     :initarg :args
     :accessor launcher-args)
    (lutris-id
     :initarg :lutris-id
     :initform nil
     :accessor launcher-lutris-id)
    (runner
     :initarg :runner
     :initform nil
     :accessor wine-runner)
    ))

(defmethod resolve-runner (runner) ;; wip for the extension
	   (declare (ignore runner))
	   "wine")

(defun wine-exec-phase (ctx)
  (let ((proc
	  (sb-ext:run-program
	   (if (wine-runner (getf ctx :launcher))
	       `,(resolve-runner (wine-runner (getf ctx :launcher)))
	       "wine")
	   (cons  (getf ctx :exec)
		  (getf ctx :args))
	   :environment (getf ctx :env)
	   :directory (pathname-directory-pathname (getf ctx :exec))
	   :search t
	   :output (or (getf ctx :log-path) *standard-output*)
	   :wait t)))
    (setf (getf ctx :process) proc)
    ctx))

(defparameter *wine-launch-pipeline*
  '((pre  . nil)
    (exec . wine-exec-phase)
    (post . nil)
    (teardown . teardown-processes)))

(defmethod launch ((l wine-launcher))
  (run-pipeline
   (apply-phase-clauses *wine-launch-pipeline* (launcher-phases l))
   `(,@(standard-ctx l)
     :args ,(or (launcher-args l) '()))))

(defmethod launcher->form ((launcher wine-launcher))
  (append (call-next-method)
	  (when (launcher-args launcher)
	    `(:args ,(launcher-args launcher)))
	  (when (launcher-lutris-id launcher)
	    `(:lutris-id ,(launcher-lutris-id launcher)))
	  (when (wine-runner launcher)
	    `(:runner ,(wine-runner launcher)))))

(defparameter *wine-basic-profile*
  '(("DXVK_ASYNC" "1")
    ("WINE_LARGE_ADDRESS_AWARE" "0")))

(define-launcher-runtime wine wine-launcher)
