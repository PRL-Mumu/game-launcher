
(in-package :game-launcher)

(defun import-launcher-form (form)
  "Read launcher form if parens match"
  (if (check-parens form) 
      (read-launcher form)
      nil))


(defun assoc-path (alist path &key (key #'identity) (test #'eql) (default nil))
  "Retrieve the value in the given ALIST represented by the given PATH"
  (or (reduce (lambda (alist k)
		(cdr (assoc k alist :key key :test test)))
	      path
	      :initial-value alist)
      default))

(defun check-parens (input)
  (let ((len (length input)))
    (cond
      ((< len 2) nil)
      ((char/= (char input 0) #\() nil)
      ((char/= (char input (1- len)) #\)) 'nil)
      (t
       (let ((depth 0))
         (loop for i from 0 below len
               for c = (char input i)
               do (cond
                    ((char= c #\() (incf depth))
                    ((char= c #\))
                     (decf depth)
                     (when (< depth 0)
                       (return-from check-parens 'wrong)))))
         (if (= depth 0) t nil))))))
