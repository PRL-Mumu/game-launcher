(in-package #:game-launcher)

(defparameter *launcher-constructors*
  ;"Runtimes register their constructor to create launcher objects"
  (make-hash-table))

(defparameter *launchers* ;"Holds launchable launcher objects"
  (make-hash-table :test #'equal))

(defparameter *unknown-launchers* ;"Holds names and forms of unrecognized forms"
  (make-hash-table :test #'equal))

(defun register-launcher (runtime constructor)
  (setf (gethash runtime *launcher-constructors*)
	constructor))

(defun register-launcher-instance (launcher)
  "Sets individual launcher object to name key"
  (setf (gethash (launcher-name launcher) *launchers*)
	launcher))

(defun register-unknown-launcher (launcher)
  "Sets unknown launcher object to name key"
  (setf (gethash (form-name launcher) *unknown-launchers*)
	launcher))

(defvar *game-launcher-store-path* nil) ;; generic path should be present

(defvar *store-path-list* nil) ;; list of store files and store tree files

(defvar *launcher-provenance* (make-hash-table :test #'equal)) ;; launcher name -> store file pathname
(defvar *unknown-provenance* (make-hash-table :test #'equal))  ;; unknown name -> store file pathname
(defvar *store-structural-forms* (make-hash-table :test #'equal)) ;; store file -> list of :store-file/:store-tree marker forms

(defun write-launchers-to-file (filepath &key source include-orphans)
  "Atomically write launcher forms to FILEPATH, keeping a .bak of any
   previous store.  Creates the containing directory as needed.  When
   SOURCE is given, only launcher/unknown definitions whose provenance is
   SOURCE are written back (so each store file keeps only its own
   definitions).  Structural forms recorded for SOURCE are appended.
   When INCLUDE-ORPHANS is true, launcher/unknown definitions with no
   recorded provenance are also written (used for the primary store)."
  (ensure-directories-exist filepath)
  (let* ((src-ns (and source (namestring source)))
         (launchers (loop for launcher being the hash-values of *launchers*
                          when (cond
                                 (include-orphans (or (null (gethash (launcher-name launcher) *launcher-provenance*))
                                                    (string= (gethash (launcher-name launcher) *launcher-provenance*) src-ns)))
                                 ((not source) t)
                                 (t (string= (gethash (launcher-name launcher) *launcher-provenance*) src-ns)))
                          collect (launcher->form launcher)))
         (unknown-launchers (loop for unknown being the hash-values of *unknown-launchers*
                                  when (cond
                                         (include-orphans (or (null (gethash (form-name unknown) *unknown-provenance*))
                                                            (string= (gethash (form-name unknown) *unknown-provenance*) src-ns)))
                                         ((not source) t)
                                         (t (string= (gethash (form-name unknown) *unknown-provenance*) src-ns)))
                                  collect (form-data unknown)))
         (structural-forms (and source (gethash source *store-structural-forms*)))
         (backup (make-pathname :type "bak" :defaults filepath))
         (tmp (make-pathname :name (format nil "~A.tmp" (or (pathname-name filepath) "store"))
                             :type (pathname-type filepath)
                             :defaults filepath)))
    (when (probe-file filepath)
      (uiop:copy-file filepath backup))
    (with-open-file (stream tmp
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (pprint (append launchers unknown-launchers structural-forms) stream))
    (rename-file tmp filepath)))

(defun write-all-stores ()
  "Write each store file back with only the launcher/unknown definitions
   that originated from it.  The primary store path keeps everything with
   no recorded provenance."
  (let ((primary (store-path)))
    (dolist (path (delete-duplicates (remove primary (store-paths)) :test #'equal))
      (when path (write-launchers-to-file path :source path)))
    (when primary (write-launchers-to-file primary :source primary :include-orphans t))))

(defun remove-launcher (name)
  (let ((launcher (gethash name *launchers*))
	(unknown  (gethash name *unknown-launchers*)))
    (when launcher
      (remhash name *launchers*)
      (let ((src (gethash name *launcher-provenance*)))
	(remhash name *launcher-provenance*)
	(when src (write-launchers-to-file src :source src))))
    (when unknown
      (remhash name *unknown-launchers*)
      (let ((src (gethash name *unknown-provenance*)))
	(remhash name *unknown-provenance*)
	(when src (write-launchers-to-file src :source src))))
    (unless (or launcher unknown)
      (write-all-stores))))

(defun resolve-location (path-var list-var &key path add candidates)
  "Resolve a location: evaluate CANDIDATES (thunks) in order, first
   non-NIL wins, after an optional explicit PATH probe.  When PATH is
   given and resolvable it becomes the new current value of PATH-VAR.
   When ADD is true the resolved location is registered in LIST-VAR
   (deduplicated by equal).  Returns the resolved pathname."
  (let ((checked (and path (probe-file path)))
        resolved)
    (dolist (cand (append (list (lambda () checked)
                                (lambda () (symbol-value path-var)))
                          candidates))
      (when (setq resolved (funcall cand))
        (return)))
    (when (and path checked (not add))
      (setf (symbol-value path-var) checked))
    (when (and resolved add)
      (pushnew resolved list-var :test #'equal))
    resolved))

(defun store-path (&key (path nil) add)
  "Resolve the store file. When PATH is given (and not :add), sets the
   current store to PATH and returns it.  When :add is true, registers
   the resolved path in *store-path-list* without clobbering the current
   store.  Falls back through GAME_LAUNCHER_STORE, the xdg config store,
   and the default bundled store."
  (resolve-location '*game-launcher-store-path* *store-path-list*
                    :path path :add add
                    :candidates (list
                                 (lambda ()
                                   (let ((p (uiop:getenv "GAME_LAUNCHER_STORE")))
                                     (when p (probe-file p))))
                                 (lambda ()
                                   (let ((user (merge-pathnames "game-launcher/launcher-store.lisp"
                                                                (uiop:xdg-config-home))))
                                     (when (probe-file user) user)))
                                 (lambda ()
                                   (merge-pathnames "src/store/launcher-store.lisp"
                                                    (asdf:system-source-directory :game-launcher))))))

(defun store-paths ()
  "All store paths: the primary store plus every registered store path."
  (delete-duplicates (cons (store-path) *store-path-list*) :test #'equal))

(defvar *unknown-form-counter* 0)

(defun make-form-name (form-data)
  "returns a number for the name, unknown launchers do not need stable names"
  (declare (ignore form-data))
  (format nil "unknown-~D"
	  (incf *unknown-form-counter*)))

(defun save-unknown-form (form)
  (make-instance 'unknown-launcher
		 :name (make-form-name form)
		 :data form))

(defun directory-store-files (directory)
  "Return all files directly in DIRECTORY, non-recursively.
  Backup files (.bak) created by write-launchers-to-file are skipped so
  they are not re-read as store files and do not clobber launcher
  provenance."
  (let ((files '()))
    (dolist (entry (cl:directory (make-pathname :defaults directory
                                                :name :wild
                                                :type :wild)))
      (when (and (pathname-name entry)
                 (not (equalp (pathname-type entry) "bak")))
        (push entry files)))
    (nreverse files)))
(defun add-store-entry (path base)  "Resolve PATH relative to BASE. If it is a directory, add every file
   in it (non-recursively) to *store-path-list*. If it is a file, add
   it directly."
  (let ((resolved (merge-pathnames path base)))
    (cond
      ((uiop:directory-pathname-p resolved)
       (dolist (f (directory-store-files resolved))
         (pushnew (truename f) *store-path-list* :test #'equal)))
      ((probe-file resolved)
       (pushnew (truename resolved) *store-path-list* :test #'equal)))))

(defun read-launcher (form &key source)
  (handler-case
      (let ((launcher (apply #'make-launcher form)))
        (register-launcher-instance launcher)
        (when source
          (setf (gethash (launcher-name launcher) *launcher-provenance*)
		(namestring source)))
        launcher)
    (unknown-runtime () ;; test
      (let ((unknown (save-unknown-form form)))
        (register-unknown-launcher unknown)
        (when source
          (setf (gethash (form-name unknown) *unknown-provenance*)
		(namestring source)))
        unknown))
    (error (e)
      (warn "Preserving malformed launcher ~%~S~%:~A~%" form e)
      (let ((unknown (save-unknown-form form)))
        (register-unknown-launcher unknown)
        (when source
          (setf (gethash (form-name unknown) *unknown-provenance*)
		(namestring source)))
        unknown))))

(defun read-launchers-from-file (filepath &key base-dir)
  "Read launcher forms from FILEPATH, resolving relative paths against
  BASE-dir (defaults to FILEPATH's own directory).  FILEPATH holds a
  single top-level list of launcher forms.  Forms beginning with
  :store-file or :store-tree are store references, not launchers — they
  are registered for loading instead of being passed to read-launcher."
  (let* ((*package* (find-package :game-launcher))
         (base-dir (or base-dir (pathname-directory-pathname (truename filepath)))))
    (with-open-file (stream filepath :direction :input)
      (let ((forms (read stream nil '()))) ; don't die on an empty store file
        (dolist (form forms)
          (cond
            ((and (consp form) (eq (car form) :store-file))
             (dolist (p (cdr form))
               (add-store-entry p base-dir))
             (push form (gethash filepath *store-structural-forms*)))
            ((and (consp form) (eq (car form) :store-tree))
             (dolist (p (cdr form))
               (let ((resolved (probe-file (merge-pathnames p base-dir))))
                 (when resolved (read-tree-file resolved))))
             (push form (gethash filepath *store-structural-forms*)))
            (t
             (read-launcher form :source (namestring filepath)))))))))

(defvar *store-tree-path* nil) ;; default store tree file, like an .asd for stores

(defun read-tree-file (filepath)
  "Read a store tree FILEPATH.  A store tree file does two things:

    - list store files to be loaded: a STRING, a list of strings, or a
      (:store-file path ...) form, all resolved relative to the tree
      file's own directory.  Directories listed have all their files
      added non-recursively.
    - run custom Lisp code: any other top-level form is EVALed in the
      :game-launcher package (e.g. defun, defparameter, etc.).

  Store files discovered are added to *store-path-list*."
  (let ((*package* (find-package :game-launcher))
        (base (pathname-directory-pathname (truename filepath))))
    (with-open-file (stream filepath :direction :input)
      (loop for form = (read stream nil 'eof)
            until (eq form 'eof)
            do (cond
                 ((stringp form)
                  (add-store-entry form base))
                 ((and (consp form) (stringp (car form)))
                  (dolist (p form)
                    (add-store-entry p base)))
                 ((and (consp form) (eq (car form) :store-file))
                  (dolist (p (cdr form))
                    (add-store-entry p base)))
                 (t
                  (eval form)))))))

(defun read-store-tree ()
  "Read the default store tree file (*store-tree-path*) if it exists."
  (when *store-tree-path*
    (read-tree-file *store-tree-path*)))

(defun load-all-stores ()
  "Read launchers from every store path registered in *store-path-list*,
  following :store-file / :store-tree references until no new stores are
  discovered (fixpoint).  Cycle-safe."
  (let ((processed (make-hash-table :test #'equal)))
    (loop
      (let ((pending (remove-if
                      (lambda (p) (gethash p processed))
                      (store-paths))))
        (when (null pending) (return))
        (dolist (path pending)
          (setf (gethash path processed) t)
          (when (probe-file path)
            (read-launchers-from-file path)))))))

(defun initialize-launcher ()
  (read-profiles-from-file (env-profile-config-path))
  (read-store-tree)
  (load-all-stores))

(defun end-launcher ()
  (write-all-stores)
  (write-profiles-to-file (env-profile-config-path))
  (uninitialize-launcher))

(defun uninitialize-launcher ()
  "only clears launchers hash, use end-launcher to write & uninitialize"
  (clrhash *launchers*)
  (clrhash *unknown-launchers*)
  (clrhash *launcher-provenance*)
  (clrhash *unknown-provenance*)
  (clrhash *store-structural-forms*))

(defmacro with-launcher-session (() &body body)
  `(unwind-protect
        (progn
          (initialize-launcher)
          ,@body)
     (end-launcher)))
