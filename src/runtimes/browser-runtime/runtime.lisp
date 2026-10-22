(in-package #:game-launcher)

(defclass browser-launcher (launcher)
  ((url
    :initarg :url
    :accessor launcher-url)
   (lutris-id
    :initarg :lutris-id
    :initform nil
    :accessor launcher-lutris-id)))

(defun make-browser-launcher (&key name profile exec url args lutris-id)
  "Create a launcher that starts a browser (EXEC) on URL with optional ARGS."
  (make-instance 'browser-launcher
                 :name name
                 :profile profile
                 :url (or exec url)
		 :exec nil ;; write url instead of exec
                 :lutris-id lutris-id))

(defun browser-exec (ctx)
  (sb-ext:run-program
   "xdg-open"
   `,(launcher-url (getf ctx :launcher))
   :environment (getf ctx :env)
   :search t
   :wait nil ;; dont wait for browser
   ))

(defparameter browser-pipeline
  '((exec . browser-exec)))

(defmethod launch ((l browser-launcher))
  (run-pipeline
   (apply-phase-clauses *browser-pipeline* (launcher-phases l))
   (standard-ctx l)))

(defmethod launcher->form ((launcher browser-launcher))
  (append (call-next-method)
          (when (launcher-url launcher)
            `(:url ,(launcher-url launcher)))
          (when (launcher-lutris-id launcher)
            `(:lutris-id ,(launcher-lutris-id launcher)))))

(define-launcher-runtime
  browser
  browser-launcher
  make-browser-launcher)
