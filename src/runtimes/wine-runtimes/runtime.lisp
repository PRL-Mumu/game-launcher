(in-package #:game-launcher)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (use-package :game-launcher))

(defclass wine-launcher (launcher)
  ( (args
     :initarg :args
     :accessor launcher-args)
    (lutris-id
     :initarg :lutris-id
     :initform nil
     :accessor launcher-lutris-id)))

(defun find-in-path (file)
  (dolist (path (uiop:split-string (uiop:getenv "PATH") :separator '(#\:)))
    (let ((candidate (merge-pathnames file (uiop:ensure-directory-pathname path))))
      (when (probe-file candidate)
        (return candidate)))))

(define-condition wine-not-found (error)
  ()
  (:report (lambda (c stream)
             (declare (ignore c))
             (format stream "wine not found in PATH"))))

(defun resolve-wine-binary ()
  (or (find-in-path "wine")
      ;; windows: defer to run-program's :search
      (if (uiop:os-windows-p)
          ""
          (error 'wine-not-found))))

(defun wine-exec-phase (ctx)
  (let ((proc (sb-ext:run-program
               (resolve-wine-binary) 
                (cons (getf ctx :exec) (split-shell-args (getf ctx :args)))
                :environment (getf ctx :env)
                :directory (pathname-directory-pathname
			    (uiop:parse-native-namestring (getf ctx :exec)))
                :search t
				:input nil
                :output (or (getf ctx :log-path) *standard-output*)
                :error (or (getf ctx :log-path) *error-output*)
                :wait nil)))
    (note-process ctx proc)
    (sb-ext:process-wait proc)
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
	    `(:lutris-id ,(launcher-lutris-id launcher)))))

(defparameter *wine-basic-profile*
  '(("DXVK_ASYNC" "1")
    ("WINE_LARGE_ADDRESS_AWARE" "0")))

(define-launcher-runtime wine wine-launcher)
