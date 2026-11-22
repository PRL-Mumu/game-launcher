(defpackage :game-launcher.desktop
  (:use :cl :game-launcher)
  (:export #:import-desktop-file))

(in-package :game-launcher.desktop)

(defparameter +desktop-field-codes+
  '("%f" "%F" "%u" "%U" "%d" "%D" "%n" "%N" "%i" "%c" "%k" "%v" "%m"
    "%w" "%W" "%g" "%G" "%s" "%h")
  "Field codes defined by the Desktop Entry spec; dropped on import since a
   launcher has no file/URL list to expand.")

(defun strip-field-codes (argv)
  "Drop standalone field-code tokens (e.g. %U) and unescape %% in ARGV.
   Codes embedded inside a token (rare) are left alone except %%."
  (loop for token in argv
        unless (member token +desktop-field-codes+ :test #'string=)
          collect (let ((out (with-output-to-string (s)
                               (loop with i = 0
                                     while (< i (length token))
                                     do (if (char= (char token i) #\%)
                                            (if (and (< (1+ i) (length token))
                                                     (char= (char token (1+ i)) #\%))
                                                (progn (write-char #\% s) (incf i 2))
                                                (progn (write-char #\% s) (incf i)))
                                            (progn (write-char (char token i) s) (incf i)))))))
                    out)))

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
      (let* ((argv (strip-field-codes (game-launcher::split-shell-args (getf data :exec))))
	     (program (first argv))
	     (rest (rest argv)))
	(when program
	  (let ((launcher (make-launcher (intern "EXEC" :game-launcher)
					     :name (getf data :name)
					     :exec program
					     :args rest)))
	    (when launcher
	      (register-launcher-instance launcher)
	      launcher)))))))
