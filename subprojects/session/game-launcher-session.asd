(defsystem #:game-launcher-session
	   :name "game-launcher-session"
	   :version "0.1.0"
	   :description "Optional session tracking for game-launcher frontends. Opt-in module: not required, not auto-loaded, no effect on the core framework."
	   :author "Rush Empire"
	   :license "GPLv3"

	   :depends-on
	   (#:game-launcher
	    #:uiop)

	   :components
	   ((:file "package")
	    (:file "session")))