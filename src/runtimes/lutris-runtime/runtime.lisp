
(in-package :game-launcher)

(defclass lutris-launcher (launcher) ())

(define-launcher-runtime lutris lutris-launcher)

(when-packages (:cl-dbi :cl-yaml :sqlite)
  (let ((here (uiop:pathname-directory-pathname *load-truename*)))
    (load (merge-pathnames "lutris.lisp" here))))
