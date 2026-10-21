
(in-package :game-launcher)

(defun import-launcher-form (form)
  (let ((*package* (find-package :game-launcher)))
    (read-launcher form)))


(defun assoc-path (alist path &key (key #'identity) (test #'eql) (default nil))
  "Retrieve the value in the given ALIST represented by the given PATH"
  (or (reduce (lambda (alist k)
		(cdr (assoc k alist :key key :test test)))
	      path
	      :initial-value alist)
      default))

; (defun import-launcher-desktop (path)
;   (format t "importing from desktop path"))
