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
  "Writes each launche form in the list to the file on its own line."
  (let ((launchers  (loop for key being the hash-values of *launchers*
                          collect (launcher->form key)))
	(unknown-launchers (loop for key being the hash-values of *unknown-launchers*
				 collect (form-data key))))
    (with-open-file (stream filename
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (pprint (append launchers unknown-launchers) stream))))

(defun store-path ();; TODO: add configuration
  (or
   (let ((user (merge-pathnames
                "game-launcher/launcher-store.lisp"
                (uiop:xdg-config-home))))
     (when (probe-file user)
       user))
   ;; bundled default
   (merge-pathnames
    "src/store/launcher-store.lisp"
    (asdf:system-source-directory :game-launcher))))

(defvar *unknown-form-counter* 0)

(defun make-form-name (form-data)
  (declare (ignore form-data))
  (format nil "unknown-~D"
          (incf *unknown-form-counter*)))

(defun save-unknown-form (form)
  (make-instance 'unknown-launcher
  		:name (make-form-name form)
		:data form))

(defun read-launchers-from-file (filename)
  (let ((*package* (find-package :game-launcher)))
    (with-open-file (stream filename :direction :input)
      (let ((forms (read stream nil '())))   ; don't die on an empty store file
	(dolist (form forms)
	  (handler-case
	    (register-launcher-instance
	      (apply #'make-launcher form))
	    (unknown-runtime () ;; test
			     (register-unknown-launcher
			       (save-unknown-form form)))
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
