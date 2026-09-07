(in-package #:game-launcher)

(defclass profile ()
  ((env :initarg :env :accessor profile-env)))

;; (make-instance 'profile
;;   :env '(("WINEPREFIX" "PREFIX_PATH")
;;          ("DXVK_ASYNC" "1")))

(defun valid-env-entry-p (entry)
  (and (consp entry)
       (= (length entry) 2)
       (stringp (first entry))
       (stringp (second entry))))

(defun make-profile (entries)
  (unless (every #'valid-env-entry-p entries)
    (error "Invalid environment entry: ~A" entries))
  (make-instance 'profile :env entries))

(defmacro env (&body entries)
  `(make-profile ',entries))

(defun env->sbcl (env)
  (mapcar (lambda (entry)
            (destructuring-bind (name value) entry
              (format nil "~A=~A" name value)))
          env))


(defun apply-profile (table env)
  "apply a profile to an existing hash table"
  (dolist (entry (profile-env env) table)
    (destructuring-bind (key value) entry
      (setf (gethash key table) value))))

(defun parse-env-entry (string)
  "split \"ENTRY=VALUE\" into \"ENTRY\" \"VALUE\""
  (let ((pos (position #\= string)))
    (values
      (subseq string 0 pos)
      (subseq string (1+ pos)))))

(defun environment->hash (environment)
  "converts env string list ((ENV=VALUE)) into a hash table"
  (let ((table (make-hash-table :test #'equal)))
    (dolist (entry environment table)
      (multiple-value-bind (key value)
                           (parse-env-entry entry)
                           (setf (gethash key table) value)))))
(defun hash->environment (table)
  "convert hash table to env string list"
  (let (result)
    (maphash
      (lambda (key value)
        (push (format nil "~A=~A" key value) result))
      table)
    result))

(defun build-environment (profile)
  "combine profile with posix environment
   and return environment"
  (hash->environment
    (apply-profile
      (environment->hash (sb-ext:posix-environ))
      profile)))

(defparameter *default-env*
  (env))

; (defparameter *my-profile*
;   (profile
;     ("PATH" "BREAK")
;     ("lol" "VAL")))

; (build-environment *my-profile*)
