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

(defun make-wine-launcher (&key name profile exec args phases lutris-id runner)
  (let ((launcher
	 (make-instance 'wine-launcher
			:name name
			:profile profile
			:exec exec
			:args args
			:phases phases
			:lutris-id lutris-id
			:runner runner)))
    launcher))

(defmethod resolve-runner (runner) ;; wip for the extension
	   (declare (ignore runner))
	   "wine")

;; (defvar *launch-pipeline*
;;   '((resolve . resolve-phase)
;;     (env     . nil)
;;     (pre     . nil)
;;     (exec    . exec-phase)
;;     (post    . nil)))

;; (defun compile-pipeline (phases)
;;   "Ordered (name . fn) list -> one closure.  fn is (ctx next) -> result;
;; nil entries are skipped.  First entry is outermost."
;;   (reduce (lambda (phase inner)
;;             (if (cdr phase)
;;                 (let ((fn (cdr phase)))
;;                   (lambda (ctx) (funcall fn ctx inner)))
;;                 inner))
;;           phases
;;           :from-end t
;;           :initial-value #'raw-launch)) suggested

;; (defmethod launch ((launcher wine-launcher))
;; 	   (let* ((exe (pathname (launcher-exec launcher)))
;; 		  (dir (pathname-directory-pathname exe)))
;; 	     (with-open-file (log "/tmp/game-launcher.wine.log"
;; 				  :direction :output
;; 				  :if-exists :append
;; 				  :if-does-not-exist :create)
;; 			     (sb-ext:run-program
;; 			      (if (wine-runner launcher) ;; simple setup
;; 				  `,(resolve-runner (wine-runner launcher)) ;; resolve path to runner
;; 				"wine") ;; use system wine
;; 			      (cons (namestring exe) (launcher-args launcher))
;; 			      :directory dir
;; 			      :environment (build-environment (launcher-profile launcher))
;; 			      :search t
;; 			      :output log
;; 			      :error log
;; 			      :wait nil))))

(defun wine-exec-phase (ctx)
  (let ((proc
	  (sb-ext:run-program
	   (if (wine-runner (ctx-launcher ctx))
	       `,(resolve-runner (wine-runner (ctx-launcher ctx)))
	       "wine")
	   (cons  (getf ctx :exec)
		  (getf ctx :args))
	   :environment (getf ctx :env)
	   :directory (pathname-directory-pathname (getf ctx :exec))
	   :search t
	   :output *standard-output*
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
   (apply-phase-clauses *wine-launch-pipeline*
                        (launcher-phases l))
   (list :launcher l
         :exec     (launcher-exec l)
         :args     (or (launcher-args l) '())
         :env      (build-environment (launcher-profile l))
         :process  nil
	 :processes nil) ;; ctx to pass around
   ))


(defmethod launcher->form ((launcher wine-launcher))
  (append (call-next-method)
	  (when (launcher-args launcher)
	    `(:args ,(launcher-args launcher)))
	  (when (launcher-lutris-id launcher)
	    `(:lutris-id ,(launcher-lutris-id launcher)))
	  (when (wine-runner launcher)
	    `(:runner ,(wine-runner launcher)))
	  (when (launcher-phases launcher)
	    `(:phases ,(launcher-phases launcher)))))

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
