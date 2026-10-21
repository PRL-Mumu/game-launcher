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

(defun unknown-launcher-list ()
  (loop for launcher being the hash-values of *unknown-launchers*
	collect launcher))

(defun select-launcher (query)
  "Fuzzy-match QUERY against launcher names; return best match or NIL."
  (first (fuzzy-match:fuzzy-match query (launcher-names))))

(defun remove-select-launcher (query)
  "Fuzzy-match QUERY and remove the best-matching launcher, persistently."
  (when-let (name (select-launcher-name query))
    (remove-launcher name)))

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

(defun list-unknown-launchers ()
  "return list of unknown launchers numerical"
  (display-launchers (unknown-launcher-list)))

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
  (bt:make-thread
   (lambda ()
     (handler-case
         (unwind-protect
              (launch launcher))
       (error (e)
         (format *error-output* "~&!! LAUNCH ERROR: ~a~%" e)
         (sb-debug:print-backtrace :stream *error-output* :count 30))))))

(defun prompt-launcher-list ()
  (let ((launchers (launcher-list)))
    (display-launchers launchers)
    (when-let (launcher (choose-launcher launchers))
      (run-launcher-thread launcher))))

(defun prompt-launcher-remove-list ()
  "display launcher list and then remove chosen launcher from *launchers*"
  (let ((launchers (launcher-list)))
    (display-launchers launchers)
    (when-let (launcher (choose-launcher launchers))
      (remove-launcher (launcher-name launcher)))))
