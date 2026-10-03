
(in-package :game-launcher)

(defclass desktop-launcher (launcher) ())

(define-launcher-runtime desktop desktop-launcher)

(when (uiop:os-unix-p)
  (let ((here (uiop:pathname-directory-pathname *load-truename*)))
    (load (merge-pathnames "desktop.lisp" here))))
