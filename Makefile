run:
	sbcl --eval '(require :asdf)' --eval '(asdf:load-system :game-launcher)' --eval '(game-launcher:main)' --eval '(sb-ext:exit)'

repl:
	sbcl --eval '(require :asdf)' --eval '(ql:quickload :game-launcher :silent t)' --eval '(in-package :game-launcher)' --eval '(initialize-launcher)'

buildcli:
	ros build roswell/game-launcher.ros

buildgui:
	ros build roswell/gamelauncher-gui.ros

install: buildcli buildgui
	[[ -e ~/.local/share/applications/game-launcher.desktop ]] || cp game-launcher.desktop ~/.local/share/applications
	install -Dm755 roswell/game-launcher ~/.roswell/bin/game-launcher
	install -Dm755 roswell/gamelauncher-gui ~/.roswell/bin/gamelauncher-gui
