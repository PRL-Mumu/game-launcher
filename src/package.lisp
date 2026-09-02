(defpackage :game-launcher
  (:use :cl )
  (:import-from :uiop
		#:xdg-config-home
		#:subdirectories
		#:pathname-directory-pathname)
  (:import-from :alexandria
		#:when-let
		#:if-let)
  (:export
   #:main
   #:launcher-names
   #:select-launcher
   #:initialize-launcher
   #:find-launcher
   #:run-launcher-thread
   #:launch
   #:launcher-name))

