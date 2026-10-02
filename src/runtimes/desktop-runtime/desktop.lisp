(in-package :game-launcher)

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
