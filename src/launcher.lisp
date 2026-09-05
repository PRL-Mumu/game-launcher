(in-package :game-launcher)

(defun launcher-names ()
  (loop for name being the hash-keys of *launchers*
        collect name))

(defun find-launcher (name)
  (gethash name *launchers*))


(defun launcher-list ()
  "collect and return a list of launchers from *launchers*"
  (loop for launcher being the hash-values of *launchers*
        collect launcher))


(defun select-launcher (query)
  (let* ((matches (fuzzy-match:fuzzy-match query (launcher-names)))
	 (choice (first matches)))
    (when choice
      (find-launcher choice))))


(defun search-launcher-list (query)
  (fuzzy-match:fuzzy-match
   query
   (launcher-list)
   :key #'launcher-name))

(defun display-launchers (launchers)
  "returns a list of launcher names"
  (loop for launcher in launchers
        for i from 1
        do (format t "~2D. ~A~%"
                   i
                   (launcher-name launcher))))

(defun list-launchers ()
  "return list of launchers numerical"
  (display-launchers (launcher-list)))

(defun choose-launcher (launchers)
  (format t "~&Choice (q to quit): ")
  (finish-output)
  (let ((input (read-line)))
    (cond
      ((string-equal input "q")
       nil)
      (t
       (let ((n (parse-integer input :junk-allowed t)))
         (when (and n
                    (<= 1 n)
                    (<= n (length launchers)))
           (nth (1- n) launchers)))))))

(defun run-launcher-thread (launcher)
  "run the launcher in a thread"
  (bt:make-thread
   (lambda ()
     (unwind-protect
	  (format t "launching ~A...~%" (launcher-name launcher))
       (launch launcher)
       (launcher-end launcher)))
   :name (format nil "Launcher: ~A" (launcher-name launcher))))

(defun launch-by-name (name)
  (let ((launcher (find-launcher name)))
    (when launcher
      (run-launcher-thread launcher))))

(defun prompt-launcher-list ()
  (let ((launchers (launcher-list)))
    (display-launchers launchers)
    (let ((launcher (choose-launcher launchers)))
      (when launcher
	(run-launcher-thread launcher)))))

(defun prompt-launcher-search ()
  (format t "~&Search: ")
  (finish-output)

  (let* ((query (read-line))
         (matches (search-launcher-list query)))
    (cond
      ((null matches)
       (format t "No matches.~%"))

      ((= (length matches) 1)
       (launch (first matches)))

      (t
       (display-launchers matches)
       (let ((launcher (choose-launcher matches)))
         (when launcher
           (launch launcher)))))))

(runtime-path)

(defun main ()
  (in-package :game-launcher)
  (with-launcher-session ()
			 (let ((args (cdr sb-ext:*posix-argv*)))
			   (if args
			     ;; Command-line mode
			     (let ((launcher (select-launcher (first args))))
			       (cond
				 (launcher
				   (format t "launching: ~A~%" (launcher-name launcher))
				   (launch launcher))
				 (t (format t "No matching launcher.~%")))
			       )

			     ;; Interactive mode
			     (prompt-launcher-list)))))


(defun entry-point ()
  (main)
  (sb-ext:exit))
