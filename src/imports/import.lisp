
(in-package :game-launcher)

(defun import-launcher-form (form)
  "Import a launcher from FORM, which may be either a string of Lisp
   source for one launcher form, or an already-read form list.
   Returns the launcher (or unknown-launcher) that was registered,
   or NIL when nothing importable was found."
  (let ((parsed (typecase form
                  (string (let ((*read-eval* nil))
                            (handler-case (read-from-string form)
                              (error (e)
                                (warn "import-launcher-form: cannot read form ~S: ~A" form e)
                                (return-from import-launcher-form nil)))))
                  (list form)
                  (t (warn "import-launcher-form: expected a string or a form, got ~S" form)
                     (return-from import-launcher-form nil)))))
    (if (and (consp parsed) (symbolp (car parsed)))
        (read-launcher parsed)
        (progn (warn "import-launcher-form: not a launcher form: ~S" parsed)
               nil))))


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
