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
   #:launcher
   #:launcherp
   #:make-launcher
   #:with-launcher-session
   ;; Frontend-facing accessors. These were historically internal (gl-tui
   ;; works around them by living in the :game-launcher package), but REST
   ;; adapters and other out-of-package frontends need them too.
   #:launcher-running-p
   #:launcher-process
   #:launcher-tags
   #:launcher-phases
   #:launcher->form
   #:launcher-args
   #:profile
   #:profile-name
   #:profile-env
   #:*named-profiles*
   #:make-profile
   #:resolve-profile
   #:valid-env-entry-p
   #:apply-phase-clauses
   #:env-profile-config-path
   #:write-profiles-to-file
   #:launcher-names
   #:display-launchers
   #:list-launchers
   #:launcher-list
   #:find-launcher
   #:remove-launcher
   #:rename-launcher
   #:unknown-runtime
   #:list-unknown-launchers
   #:register-launcher
   #:register-launcher-instance
   #:select-launcher
   #:initialize-launcher
   #:end-launcher
   #:uninitialize-launcher
   #:import-launcher-form
   #:run-launcher-thread
   #:launch
   #:launcher-name
   #:launcher-runtime
   #:launcher-exec
   #:launcher-profile
   #:stop-launcher
   #:unknown-launcher-list
   #:write-launchers-to-file
   #:write-all-stores
   #:search-launcher-list
   #:select-launcher-name
   #:load-runtime
   #:reload-runtime
   #:resolve-launcher-log-path
   #:prompt-launcher-list
   #:prompt-launcher-remove-list
   #:runtime-path
   #:runtime-paths
   #:store-path
   #:store-paths
   #:known-runtimes
   #:split-shell-args
   #:define-launcher-runtime
   #:rush-debug-load-runtimes))
