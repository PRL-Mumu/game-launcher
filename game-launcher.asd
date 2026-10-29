(defsystem #:game-launcher
	   :name "game-launcher"
	   :version "0.2.5"
	   :description "Simple game launcher framework written in common lisp"
	   :author "Rush Empire"
	   :license "GPLv3"

	   :depends-on
	   (#:uiop
	    #:fuzzy-match
	    #:bordeaux-threads
	    #:closer-mop)
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
		      (:file "launch-pipeline")
		      (:file "unknown-launcher-class")))
	    (:module "imports"
		     :components ((:file "import")))
	    (:file "launcher")))
