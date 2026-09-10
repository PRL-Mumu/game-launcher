(defsystem #:game-launcher
	   :name "game-launcher"
	   :version "0.2.0"
	   :description "Simple game launcher written in common lisp"
	   :author "Rush Empire"
	   :license "GPLv3"

	   :depends-on
	   (#:uiop
	    #:fuzzy-match
	    #:bordeaux-threads
	    #+linux #:cl-yaml
	    #+linux #:cl-dbi
	    #+linux #:dbd-sqlite3
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
		     :components ((:file "import")
				  (:file "steam")
				  #+linux (:file "lutris")
				  (:file "desktop")))
	    (:file "launcher")))
