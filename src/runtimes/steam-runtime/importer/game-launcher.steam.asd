(defsystem #:game-launcher.steam
	   :name "game-launcher.steam"
	   :version "0.0.5"
	   :description "Steam game launcher framework extension written in common lisp"
	   :author "Rush Empire"
	   :license "GPLv3"

	   :depends-on
	   (#:game-launcher
	    #:dexador
	    #:cl-json)

	   :components (
			(:file "steam-acf")
			(:file "steam")
			))
