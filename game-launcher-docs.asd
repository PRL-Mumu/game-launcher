(defsystem "game-launcher-docs"
  :name "game-launcher-docs"
  :version "0.1.0"
  :description "Guide documentation site for the game-launcher Common Lisp framework."
  :author "Rush"
  :license "GPLv3"
  :depends-on ("uiop"
               "3bmd"
               "3bmd-ext-code-blocks"
               "3bmd-ext-tables"
               "spinneret"
               "hunchentoot")
  :serial t
  :components ((:module "src"
                :components ((:file "package")
                             (:file "site")
                             (:file "render")
                             (:file "build")))))
