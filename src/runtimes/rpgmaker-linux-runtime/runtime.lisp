(in-package #:game-launcher)


(defclass rpgmaker-linux-launcher (launcher)
  ())

(defun make-rpgmaker-linux-launcher (&key name profile exec)
  "Create a launcher: an executable-launcher on Windows, an
rpgmaker-linux-launcher on Unix."
  (cond
    ((uiop:os-windows-p)
     (make-instance 'executable-launcher
                    :name name
                    :profile profile
                    :exec exec
                    :args nil))
    ((uiop:os-unix-p)
     (make-instance 'rpgmaker-linux-launcher
                    :name name
                    :profile profile
                    :exec exec))))

(defmethod launch ((launcher rpgmaker-linux-launcher))
  (let* ((exe (pathname (launcher-exec launcher)))
	 (dir (pathname-directory-pathname exe)))
    (sb-ext:run-program
      "rpgmaker-linux"
      (list (namestring exe))
      :directory dir
      :environment (build-environment (launcher-profile launcher))
      :search t
      :output *standard-output*
      :wait nil)))

(define-launcher-runtime  ;; macro
  rpgmaker 
  rpgmaker-linux-launcher 
  make-rpgmaker-linux-launcher)
