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
    #:launcher
    #:launcherp
    #:make-launcher
    #:with-launcher-session
    #:launcher-names
    #:display-launchers
    #:list-launchers
    #:launcher-list
    #:list-unknown-launchers
    #:register-launcher-instance
    #:select-launcher
    #:initialize-launcher
    #:import-launcher-form
    #:uninitialize-launcher
    #:find-launcher
    #:remove-launcher
    #:run-launcher-thread
    #:launch
    #:launcher-name
    #:launcher-runtime
    #:launcher-exec
    #:launcher-profile
    #:unknown-launcher-list
    #:write-launchers-to-file
    #:search-launcher-list
    #:select-launcher-name
    #:load-runtime
    #:prompt-launcher-list
    #:prompt-launcher-remove-list
    #:runtime-path
    #:store-path
    #:export-runtime-symbol-into-core
    #:known-runtimes
    #:rush-debug-load-runtimes))
