(defsystem #:game-launcher
	   :name "game-launcher"
	   :version "0.0.1"
	   :description "Simple game launcher written in common lisp"
	   :author "Rush Empire"
	   :license "GPLv3"

	   :depends-on
	   (#:uiop
	    #:fuzzy-match
	    #:bordeaux-threads
	    #:cl-dbi
	    #:dbd-sqlite3
	    #:cl-json
	    #:dexador)

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
