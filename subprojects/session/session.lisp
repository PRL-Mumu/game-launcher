(in-package :game-launcher-session)

(defstruct session
  ;; A session keeps one stable id (and file path) for its whole life,
  ;; so GAME_LAUNCHER_SESSION can keep pointing at it while the pid
  ;; and log path are filled in after spawn.
  (id (format nil "~D-~D" (get-universal-time) (random #x10000000)) :type string)
  (name nil :type string)
  (pid 0 :type integer)
  (runtime nil :type (or symbol string null))
  (log nil :type (or pathname string null))
  (started (get-universal-time) :type integer)
  (data nil :type list))

(defun sessions-directory ()
  "Directory that holds session files; created on demand."
  (let ((dir (merge-pathnames "game-launcher/sessions/" (uiop:xdg-data-home))))
    (ensure-directories-exist dir)
    dir))

(defun sanitize-component (name)
  "Make NAME safe as a file-name component: alphanumerics, - _ . and
   spaces kept, everything else replaced with -, limited in length."
  (with-output-to-string (out)
    (loop for ch across name
          for i from 0 below 64
          do (cond ((or (alphanumericp ch) (find ch "-_ ."))
                    (write-char ch out))
                   (t
                    (write-char #\- out))))))

(defun session-path (session)
  "The stable session file path for SESSION (id + name)."
  (merge-pathnames
   (format nil "~A-~A.lisp"
           (session-id session)
           (sanitize-component (session-name session)))
   (sessions-directory)))

(defun session->plist (s)
  (list :id (session-id s)
        :name (session-name s)
        :pid (session-pid s)
        :runtime (session-runtime s)
        :log (if (session-log s) (namestring (session-log s)) nil)
        :started (session-started s)
        :data (session-data s)))

(defun plist->session (pl)
  (make-session :id (or (getf pl :id)
                        (format nil "~D-~D" (or (getf pl :started) (get-universal-time))
                                (random #x10000000)))
                :name (getf pl :name)
                :pid (getf pl :pid)
                :runtime (getf pl :runtime)
                :log (getf pl :log)
                :started (or (getf pl :started) (get-universal-time))
                :data (getf pl :data)))

(defun sessions-matching (name &optional (test #'string=))
  "All session files whose :name matches NAME under TEST."
  (let ((dir (sessions-directory))
        (result '()))
    (when (probe-file dir)
      (dolist (file (cl:directory (make-pathname :defaults dir :name :wild :type "lisp")))
        (when (pathname-name file)
          (let ((s (ignore-errors (read-session-file file))))
            (when (and s (funcall test (session-name s) name))
              (push s result))))))
    (nreverse result)))

(defun read-session-file (file)
  (let ((*read-eval* nil)
        (*package* (find-package :game-launcher-session)))
    (with-open-file (in file :direction :input)
      (let ((form (read in nil nil)))
        (when (and (consp form) (eq (car form) :id))
          (plist->session form))))))

(defun write-session (session)
  "Create or update SESSION's file atomically. The path is stable
   (derived from the session id), so rewriting with new pid/log values
   updates the same file."
  (let* ((final (session-path session))
         (tmp (make-pathname :name (format nil "~A.tmp" (pathname-name final))
                             :type (pathname-type final)
                             :defaults final)))
    (ensure-directories-exist final)
    (with-open-file (out tmp
                         :direction :output
                         :if-does-not-exist :create
                         :if-exists :supersede)
      (let ((*print-length* nil)
            (*print-level* nil))
        (prin1 (session->plist session) out)))
    (rename-file tmp final))
  session)

(defun alive-p (session)
  "Liveness check for a session whose pid we only know from its record.
   pid 0 means the process never spawned: treated as not alive.
   On Linux uses /proc/<pid>; on macOS uses sb-posix:kill 0; elsewhere
   assumes alive."
  (let ((pid (session-pid session)))
    (and pid
         (plusp pid)
         (cond
           ((probe-file "/proc")
            (probe-file (format nil "/proc/~D" pid)))
           #+darwin (ignore-errors (sb-posix:kill pid 0))
           #-darwin (t t)))))

(defun read-session (name)
  "Return the most recently started live session named NAME, or NIL."
  (let ((candidates (remove-if-not #'alive-p (sessions-matching name))))
    (car (sort candidates (lambda (a b) (> (session-started a) (session-started b)))))))

(defun all-sessions ()
  "Return all sessions whose process is still alive (dead ones pruned)."
  (prune-sessions)
  (let ((dir (sessions-directory))
        (result '()))
    (when (probe-file dir)
      (dolist (file (cl:directory (make-pathname :defaults dir :name :wild :type "lisp")))
        (when (pathname-name file)
          (let ((s (ignore-errors (read-session-file file))))
            (when (and s (alive-p s))
              (push s result))))))
    (nreverse result)))

(defun find-session (name)
  "Alias for READ-SESSION; return the most recent live session named NAME."
  (read-session name))

(defun update-session-data (session plist)
  "Merge PLIST (as :k v ...) into SESSION's data plist and persist."
  (let ((data (copy-list (session-data session))))
    (loop for (k v) on plist by #'cddr
          do (setf (getf data k) v))
    (let ((new (make-session :id (session-id session)
                             :name (session-name session)
                             :pid (session-pid session)
                             :runtime (session-runtime session)
                             :log (session-log session)
                             :started (session-started session)
                             :data data)))
      (setf (session-data session) data)
      (write-session new))))

(defun prune-sessions ()
  "Delete session files whose :pid no longer exists. Returns count removed."
  (let ((dir (sessions-directory))
        (removed 0))
    (when (probe-file dir)
      (dolist (file (cl:directory (make-pathname :defaults dir :name :wild :type "lisp")))
        (when (pathname-name file)
          (let ((s (ignore-errors (read-session-file file))))
            (when (and s (not (alive-p s)))
              (ignore-errors (delete-file file))
              (incf removed))))))
    removed))