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
    (unless pos
      (error "Invalid environment entry ~S: missing '='" string))
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

(defun build-environment (&rest profiles)
  "Combine the POSIX environment with zero or more profiles.
Later profiles win on key collisions. Returns a string list."
  (let ((table (environment->hash (sb-ext:posix-environ))))
    (dolist (p profiles)
      (apply-profile table p))
    (hash->environment table)))

(defun env-profile-config-path ()
  (merge-pathnames "game-launcher/profiles.lisp" (uiop:xdg-config-home)))

(defun write-profiles-to-file (filename)
  (ensure-directories-exist filename)
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
                         (make-instance 'profile :name spec :env nil))))
    (string   (let ((sym (find-symbol (string-upcase spec) :game-launcher)))
                (if sym
                    (resolve-profile sym)
                    (progn (warn "unknown profile ~S" spec)
                           (make-instance 'profile :name (intern (string-upcase spec)) :env nil)))))
    (t        (warn "unknown profile spec ~S" spec)
              (make-instance 'profile))))



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
                   ((null (cdr items))
                    (error "Odd-length launcher argument plist: dangling key ~S" (car items)))
                   (t (destructuring-bind (k v &rest r) items
                        (walk r (list* v k clean)))))))
    (walk plist nil)))

(defun marker->name (marker)
  (intern (string-trim "*=>" (symbol-name marker))
          (find-package :game-launcher)))

(defun ensure-profile (name env)
  (let ((existing (gethash name *named-profiles*)))
    (if (null env)
        ;; no inline env given: keep any existing profile untouched,
        ;; create an empty one only if none exists
        (or existing
            (let ((p (make-instance 'profile :name name :env nil)))
              (setf (gethash name *named-profiles*) p)
              p))
        (let ((pairs (profile-env (make-profile env))))
          (if existing
              (progn (setf (profile-env existing) pairs) existing)
              (let ((p (make-instance 'profile :name name :env pairs)))
                (setf (gethash name *named-profiles*) p)
                p))))))
