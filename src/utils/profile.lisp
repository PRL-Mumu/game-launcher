(in-package #:game-launcher)

(defclass profile ()
  ((name :initarg :name :initform nil :accessor profile-name)
   (env  :initarg :env  :initform nil :accessor profile-env)))

;; add =><custom-profile-name> to the end of a :PROFILE block to store it
(defparameter *named-profiles* (make-hash-table)) 

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

(defun env-profile-config-path ()
  (merge-pathnames "game-launcher/profiles.lisp" (uiop:xdg-config-home)))

(defun write-profiles-to-file (filename)
  (with-open-file (stream filename :direction :output
                          :if-exists :supersede :if-does-not-exist :create)
    (let ((*package* (find-package :game-launcher))
          (*print-length* nil) (*print-level* nil))
      (loop for sym being the hash-keys of *named-profiles*
            for p = (gethash sym *named-profiles*)
            do (pprint `(profile :name ,sym :env ,(profile-env p)) stream)
               (terpri stream)))))

(defun read-profiles-from-file (filename)
  (when (probe-file filename)
    (let ((*package* (find-package :game-launcher))
          (*read-eval* nil))                       ; no #. in a config file
      (with-open-file (stream filename :direction :input)
        (loop for form = (handler-case (read stream nil nil)
                           (error (e)
                             (warn "profiles.lisp: bad form at end of read: ~A" e)
                             nil))
              while form
              do (handler-case
                     (let ((name (getf (cdr form) :name))
                           (env  (getf (cdr form) :env)))
                       (setf (gethash name *named-profiles*)
                             (make-instance 'profile :name name :env env)))
                   (error (e)
                     (warn "profiles.lisp: skipping bad profile ~S: ~A" form e))))))))

(defun resolve-profile (spec)
  (typecase spec                              ; typecase, not etypecase
    (profile  spec)                           ; already resolved — no-op
    (null     (make-instance 'profile))
    (list     (make-profile spec))
    (symbol   (or (gethash spec *named-profiles*)
                  (progn (warn "unknown profile ~S" spec)
                         (make-instance 'profile :name spec :env nil))))))

(defun save-profile (symbol env)
  "Register SYMBOL as a named profile with ENV pairs; persists to profiles.lisp."
  (setf (gethash symbol *named-profiles*)
        (make-instance 'profile :name symbol :env (make-profile env)))
  (write-profiles-to-file (env-profile-config-path)))

(defun name-launcher-profile (launcher symbol)
  "Turn LAUNCHER's inline profile into a named one."
  (save-profile symbol (profile-env (launcher-profile launcher)))
  (setf (launcher-profile launcher)
        (make-instance 'profile :name symbol
                                :env (profile-env (launcher-profile launcher)))))

(defun profile-spec (profile)
  (if (profile-name profile)
      (profile-name profile)         
      (profile-env profile)))         

(defun split-profile-marker (plist)
  "Clean a launcher-args plist: remove a =>NAME marker wherever it sits.
Returns (VALUES clean-plist marker), marker the NAME symbol or nil."
  (labels ((walk (items clean)
             (cond ((null items) (values (nreverse clean) nil))
                   ((and (symbolp (car items))
                         (eql (search "=>" (symbol-name (car items))) 0))
                  (multiple-value-bind (rest marker) (walk (cdr items) clean)
                    (values rest (or (car items) marker))))
                   (t (destructuring-bind (k v &rest r) items
                        (walk r (list* v k clean)))))))
    (walk plist nil)))

(defun marker->name (marker)
  (intern (string-trim "*=>" (symbol-name marker))
          (find-package :game-launcher)))

(defun ensure-profile (name env)
  (let ((pairs (profile-env (make-profile env))))  
    (let ((existing (gethash name *named-profiles*)))
      (if existing
          (progn (setf (profile-env existing) pairs) existing)
          (let ((p (make-instance 'profile :name name :env pairs)))
            (setf (gethash name *named-profiles*) p)
            p)))))

(defparameter *default-env*
  (env))

