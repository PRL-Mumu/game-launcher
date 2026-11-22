(defpackage :game-launcher-session
  (:use :cl)
  (:export #:session
	   #:session-name
	   #:session-pid
	   #:session-runtime
	   #:session-log
	   #:session-started
	   #:session-data
	   #:session-id
	   #:session-p
	   #:make-session
	   #:sessions-directory
	   #:session-path
	   #:write-session
	   #:read-session
	   #:all-sessions
	   #:find-session
	   #:update-session-data
	   #:prune-sessions))