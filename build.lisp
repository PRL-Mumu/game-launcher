(require :asdf)
(load (merge-pathnames "quicklisp/setup.lisp"
                       (user-homedir-pathname)))

(asdf:load-system :game-launcher)

(sb-ext:save-lisp-and-die
 "game-launcher"
 :toplevel #'game-launcher::main
 :executable t)
