
(in-package :game-launcher)

(defun import-launcher-form (form)
  (let ((*package* (find-package :game-launcher)))
    (handler-case
        (register-launcher-instance
         (apply #'make-launcher form))
      (unknown-runtime ()
        (register-unknown-launcher
         (save-unknown-form form)))
      (error (e)
        (warn "Could not import launcher ~S: ~A" form e)))))

; (defun import-launcher-desktop (path)
;   (format t "importing from desktop path"))

(defun parse-desktop-file (path)
  "Parse a .desktop file and return a property list"
  (let ((name nil)
        (exec nil)
        (path-dir nil))
    (with-open-file (stream path :direction :input)
      (loop for line = (read-line stream nil)
            while line
            do (cond ((and (not name) (cl-ppcre:scan "^Name=" line))
                      (setf name (subseq line 5)))
                     ((and (not exec) (cl-ppcre:scan "^Exec=" line))
                      (setf exec (subseq line 5)))
                     ((and (not path-dir) (cl-ppcre:scan "^Path=" line))
                      (setf path-dir (subseq line 5))))))
    (list :name name :exec exec :working-directory path-dir)))

(defun import-desktop-file (path)
  "Import a game from a .desktop file"
  (let ((data (parse-desktop-file path)))
    (when (and (getf data :name) (getf data :exec))
      (register-launcher-instance 
	(let ((exec (uiop:split-string (getf data :exec))))
	  (make-launcher 'exec
			 :name (getf data :name)
			 :exec (first exec)
			 :args (rest exec)))))))

(defstruct lutris-game
  id
  name
  slug
  platform
  runner
  executable
  directory
  configpath
  installed)

(defun import-lutris (db-path)
  (dolist (game (parse-lutris-database db-path))
    (let ((yaml-path (lutris-yaml-path game)))
      (when (probe-file yaml-path)
        (import-lutris-game
         game
         (parse-lutris-yaml yaml-path))))))

(defun import-lutris-game (id))


