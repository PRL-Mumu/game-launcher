LISP ?= sbcl

.PHONY: build serve clean

build:
	$(LISP) --non-interactive --load build.lisp

serve:
	$(LISP) --non-interactive --load serve.lisp

clean:
	rm -rf site
