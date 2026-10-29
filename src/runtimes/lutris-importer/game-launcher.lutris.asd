(defsystem #:game-launcher.lutris
	   :description "lutris game launcher framework extension written in common lisp"
	   :author "Rush Empire"
	   :license "GPLv3"

	   :depends-on
	   (#:game-launcher
            #:cl-dbi 
	    #:cl-yaml 
	    #:dbd-sqlite3)

	   :components (
			(:file "lutris")
			))
