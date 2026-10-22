(in-package #:game-launcher)

(defclass steam-launcher (launcher)
  ())

(defun make-steam-launcher (&key name profile exec phases)
	  (make-instance 'steam-launcher
			 :name name
			 :profile profile
			 :exec exec
			 :phases phases))


(defun steam-exec (ctx)
  (setf (getf ctx :process)
	(sb-ext:run-program
	 "steam"
	 (list (getf ctx :exec))
	 :environment (getf ctx :env)
	 :search t
	 :wait nil))) ;; dont wait for steam

(defparameter *steam-pipeline*
  '((exec . steam-exec)))

(defmethod launch ((l steam-launcher))
  (run-pipeline
   (apply-phase-clause *steam-pipeline* (launcher-phases l))
   (standard-ctx l)))

(define-launcher-runtime
  steam
  steam-launcher
  make-steam-launcher)

;; extras
;; NOTE: NEEDS Dexador and cl-lisp packages
(when-packages (:dexador :cl-json)
  (let ((here (uiop:pathname-directory-pathname *load-truename*)))
    (load (merge-pathnames "steam-acf.lisp" here))
    (load (merge-pathnames "steam.lisp" here))))
;; ;; ;;
