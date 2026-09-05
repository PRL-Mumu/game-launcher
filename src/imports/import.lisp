
(in-package :game-launcher)

(defun import-launcher-form (form)
  (let ((*package* (find-package :game-launcher)))
    (handler-case
        (register-launcher-instance
         (apply #'make-launcher form))
      (unknown-runtime ()
        (register-unknown-launcher
         (save-unknown-form form)))
      (error (e)
        (warn "Could not import launcher ~S: ~A" form e)))))
