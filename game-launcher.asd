(defsystem #:game-launcher
	   :name "game-launcher"
	   :version "0.2.2"
	   :description "Simple game launcher written in common lisp"
	   :author "Rush Empire"
	   :license "GPLv3"

	   :depends-on
	   (#:uiop
	    #:fuzzy-match
	    #:bordeaux-threads
	    #:cl-hooks ;; unused
	    )
	   :pathname "src"

	   :components
	   ((:file "package")
	    (:module "utils"
		     :components
		     ((:file "profile")))
	    (:file "registry")
	    (:module "runtimes"
		     :components
		     ((:file "launcher-class")
		      (:file "unknown-launcher-class")))
	    (:module "imports"
		     :components ((:file "import")))
	    (:file "launcher")))
