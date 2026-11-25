(require :asdf)

(let ((quicklisp (merge-pathnames "quicklisp/setup.lisp"
                                  (user-homedir-pathname))))
  (when (probe-file quicklisp)
    (load quicklisp)))

(asdf:load-system :game-launcher-docs)

(let* ((arguments (uiop:command-line-arguments))
       (port (and arguments
                  (parse-integer (first arguments) :junk-allowed t))))
  (game-launcher-docs:serve-site :port (or port 4173)))
