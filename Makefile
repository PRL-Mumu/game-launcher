run:
	sbcl --eval '(require :asdf)' --eval '(asdf:load-system :game-launcher)' --eval '(game-launcher:main)' --eval '(sb-ext:exit)'

repl:
	sbcl --eval '(require :asdf)' --eval '(asdf:load-system :game-launcher)' --eval '(in-package :game-launcher)' --eval '(initialize-launcher)'

build:
	sbcl --script build.lisp

install: build
	mv game-launcher ~/.local/bin/
