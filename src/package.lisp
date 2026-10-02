(defpackage :game-launcher
  (:use :cl)
  (:import-from :uiop
		#:xdg-config-home
		#:subdirectories
		#:pathname-directory-pathname)
  (:import-from :alexandria
		#:when-let
		#:if-let)
  (:export
    #:assoc-path
    #:main
    #:make-launcher
    #:launcher-names
    #:list-launchers
    #:list-unknown-launchers
    #:register-launcher-instance
    #:select-launcher
    #:initialize-launcher
    #:uninitialize-launcher
    #:find-launcher
    #:run-launcher-thread
    #:launch
    #:launcher-name
    #:load-runtime
    #:runtime-path
    #:export-runtime-symbol-into-core
    #:rush-debug-load-runtimes))
