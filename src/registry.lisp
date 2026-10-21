(in-package #:game-launcher)

(defparameter *launcher-constructors*
  (make-hash-table))

(defparameter *launchers*
  (make-hash-table :test #'equal))

(defparameter *unknown-launchers*
  (make-hash-table :test #'equal))

(defun register-launcher (runtime constructor)
  (setf (gethash runtime *launcher-constructors*)
	constructor))

(defun register-launcher-instance (launcher)
  (setf (gethash (launcher-name launcher) *launchers*)
	launcher))

(defun register-unknown-launcher (launcher)
  (setf (gethash (form-name launcher) *unknown-launchers*)
	launcher))

(defun write-launchers-to-file (filename)
  "Writes each launcher form in the list to the file on its own line."
  (let ((launchers  (loop for key being the hash-values of *launchers*
			  collect (launcher->form key)))
	(unknown-launchers (loop for key being the hash-values of *unknown-launchers*
				 collect (form-data key))))
    (with-open-file (stream filename
			    :direction :output
			    :if-exists :supersede
			    :if-does-not-exist :create)
      (pprint (append launchers unknown-launchers) stream))))

(defun remove-launcher (name)
  (unless (remhash name *launchers*)
    (remhash name *unknown-launchers*))
  (write-launchers-to-file (store-path)))

(defvar *game-launcher-store-path* nil)

(defun store-path (&optional path)
  (let* ((checked-path (and path (setf *game-launcher-store-path* (probe-file path))))
         (current-store *game-launcher-store-path*)
         (env-store (let ((p (uiop:getenv "GAME_LAUNCHER_STORE")))
                      (when p (probe-file p))))
         (user-store (let ((user (merge-pathnames
                                   "game-launcher/launcher-store.lisp"
                                   (uiop:xdg-config-home))))
                       (when (probe-file user) user)))
         (default-store (merge-pathnames
                          "src/store/launcher-store.lisp"
                          (asdf:system-source-directory :game-launcher))))
    (or checked-path
        current-store
        env-store
        user-store
        default-store)))

(defvar *unknown-form-counter* 0)

(defun make-form-name (form-data)
  "returns a number for the name, unknown launchers do not need stable names"
  (declare (ignore form-data))
  (format nil "unknown-~D"
	  (incf *unknown-form-counter*)))

(defun save-unknown-form (form)
  (make-instance 'unknown-launcher
		 :name (make-form-name form)
		 :data form))

(defun read-launcher (form)
  (handler-case
      (register-launcher-instance
       (apply #'make-launcher form))
    (unknown-runtime () ;; test
      (register-unknown-launcher
       (save-unknown-form form)))
    (error (e)
      (warn "Preserving malformed launcher ~%~S~%:~A~%" form e)
      (register-unknown-launcher (save-unknown-form form)))))

(defun read-launchers-from-file (filename)
  (let ((*package* (find-package :game-launcher)))
    (with-open-file (stream filename :direction :input)
      (let ((forms (read stream nil '()))) ; don't die on an empty store file
	(dolist (form forms)
	  (read-launcher form))))))


(defun initialize-launcher ()
  (read-profiles-from-file (env-profile-config-path))
  (read-launchers-from-file (store-path)))

(defun end-launcher ()
  (write-launchers-to-file (store-path))
  (write-profiles-to-file (env-profile-config-path))
  (uninitialize-launcher))

(defun uninitialize-launcher ()
  (clrhash *launchers*)
  (clrhash *unknown-launchers*))

(defmacro with-launcher-session (() &body body)
  `(unwind-protect
        (progn
          (initialize-launcher)
          ,@body)
     (end-launcher)))
