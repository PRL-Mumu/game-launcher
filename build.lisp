(require :asdf)

(let ((quicklisp (merge-pathnames "quicklisp/setup.lisp"
                                  (user-homedir-pathname))))
  (when (probe-file quicklisp)
    (load quicklisp)))

(asdf:load-system :game-launcher-docs)
(game-launcher-docs:build-site)
