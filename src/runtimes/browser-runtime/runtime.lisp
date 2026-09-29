(in-package #:game-launcher)

;; ----------------------------------------------------------------------
;;  Browser launcher class
;; ----------------------------------------------------------------------
(defclass browser-launcher (launcher)
  ((url
    :initarg :url
    :accessor launcher-url)
   (args
    :initarg :args
    :accessor launcher-args)
   (lutris-id
    :initarg :lutris-id
    :initform nil
    :accessor launcher-lutris-id)))

(defun make-browser-launcher (&key name profile exec url args lutris-id)
  "Create a launcher that starts a browser (EXEC) on URL with optional ARGS."
  (make-instance 'browser-launcher
                 :name      name
                 :profile   profile
                 :exec      exec          ; e.g. \"/usr/bin/firefox\"
                 :url       url
                 :args      args
                 :lutris-id lutris-id))

;; ----------------------------------------------------------------------
;;  Launch – start the browser process
;; ----------------------------------------------------------------------
(defmethod launch ((launcher browser-launcher))
  (let* ((exe   (pathname (launcher-exec launcher)))
         (url   (launcher-url launcher))
         (full-args (append (launcher-args launcher) (list url))))
    (with-open-file (log "/tmp/game-launcher.browser.log"
                         :direction :output
                         :if-exists :append
                         :if-does-not-exist :create)
      (sb-ext:run-program
        (namestring exe)
        full-args
        :environment (build-environment (launcher-profile launcher))
        :search t
        :output log
        :error  log
        :wait nil))))

;; ----------------------------------------------------------------------
;;  Convert launcher to a form (for serialization, etc.)
;; ----------------------------------------------------------------------
(defmethod launcher->form ((launcher browser-launcher))
  (append (call-next-method)
          (when (launcher-url launcher)
            `(:url ,(launcher-url launcher)))
          (when (launcher-args launcher)
            `(:args ,(launcher-args launcher)))
          (when (launcher-lutris-id launcher)
            `(:lutris-id ,(launcher-lutris-id launcher)))))

;; ----------------------------------------------------------------------
;;  Kill – ask the browser to exit (best‑effort)
;; ----------------------------------------------------------------------
(defmethod kill ((launcher browser-launcher))
  ;; Most browsers understand “-remote quit” or “--new-instance --no-remote”.
  ;; We keep it generic: try to kill the process tree of the launched exe.
  (sb-ext:run-program
    "pkill"
    (list "-f" (launcher-exec launcher))
    :search t
    :output *standard-output*
    :wait t))

;; ----------------------------------------------------------------------
;;  End of launcher lifecycle
;; ----------------------------------------------------------------------
(defmethod launcher-end ((launcher browser-launcher))
  (format t "Browser launcher thread ENDED~%")
  (kill launcher)
  nil)

;; ----------------------------------------------------------------------
;;  Status reporting
;; ----------------------------------------------------------------------
(defmethod status ((launcher browser-launcher)
                   &optional (stream *standard-output*))
  (format stream "NAME: ~A~%" (launcher-name launcher))
  (format stream "ENV : ~A~%" (profile-env (launcher-profile launcher)))
  (format stream "EXEC: ~A~%" (launcher-exec launcher))
  (format stream "URL : ~A~%" (launcher-url launcher))
  (format stream "ARGS: ~A~%" (launcher-args launcher)))

;; ----------------------------------------------------------------------
;;  Example of a basic profile for browsers (optional)
;; ----------------------------------------------------------------------
(defparameter *browser-basic-profile*
  '(("MOZ_DISABLE_OOP" "1")   ; example for Firefox
    ("CHROME_NO_SANDBOX" "1")))

;; ----------------------------------------------------------------------
;;  Register the new runtime with the framework
;; ----------------------------------------------------------------------
(define-launcher-runtime
  browser
  browser-launcher
  make-browser-launcher)
