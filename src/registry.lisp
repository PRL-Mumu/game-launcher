(in-package #:game-launcher)

(defparameter *launcher-constructors*
  (make-hash-table))

(defparameter *launchers*
  (make-hash-table :test #'equal))

(defun register-launcher (runtime constructor)
  (setf (gethash runtime *launcher-constructors*)
        constructor))

(defun register-launcher-instance (launcher)
  (setf (gethash (launcher-name launcher) *launchers*)
        launcher))

(defun write-launchers-to-file (filename)
  "Writes each command in the list to the file on its own line."
  (let ((launchers  (loop for key being the hash-values of *launchers*
                          collect (launcher->form key))))
    (with-open-file (stream filename
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (pprint launchers stream))))


; (defun read-launchers-from-file (filename)
;   (with-open-file (stream filename :direction :input)
;     (dolist (form (read stream))
;       (register-launcher-instance (eval form)))))

(defun store-path ()
  (or
   ;; command-line override
   (let ((user (merge-pathnames
                "game-launcher/launcher-store.lisp"
                (uiop:xdg-config-home))))
     (when (probe-file user)
       user))
   ;; bundled default
   (merge-pathnames
    "src/store/launcher-store.lisp"
    (asdf:system-source-directory :game-launcher))))

(defun read-launchers-from-file (filename)
  (let ((*package* (find-package :game-launcher)))
    (with-open-file (stream filename :direction :input)
      (let ((forms (read stream nil '())))   ; don't die on an empty store file
        (dolist (form forms)
          (handler-case
              (register-launcher-instance
               (apply #'make-launcher form))
            (unknown-runtime (e)
              (warn "Skipping launcher with unknown runtime: ~A" e))
            (error (e)
              (warn "Skipping launcher ~S: ~A" form e))))))))


(defmacro with-launcher-session (() &body body)
  `(progn
     (read-launchers-from-file (store-path))
     (unwind-protect
          (progn ,@body)
       (write-launchers-to-file (store-path)))))

(defun initialize-launcher ()
  (runtime-path)
  (read-launchers-from-file (store-path)))
