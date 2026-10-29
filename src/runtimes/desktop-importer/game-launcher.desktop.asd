(defsystem #:game-launcher.desktop
	   :description "desktop game launcher framework extension written in common lisp"
	   :author "Rush Empire"
	   :license "GPLv3"

	   :depends-on
	   (#:game-launcher)

	   :components (
			(:file "desktop")
			))
