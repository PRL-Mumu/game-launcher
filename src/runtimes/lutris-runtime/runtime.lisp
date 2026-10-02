
(in-package :game-launcher)

(defclass lutris-launcher (launcher) ())

(define-launcher-runtime lutris lutris-launcher)

(when-packages (:cl-dbi :cl-yaml :dbd-sqlite3)
  (let ((here (make-pathname :name nil :type nil :defaults *load-truename*)))
    (load (merge-pathnames "lutris.lisp" here))))
