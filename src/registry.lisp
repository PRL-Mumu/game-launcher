(in-package #:game-launcher)

(defparameter *launcher-constructors*
  ;"Runtimes register their constructor to create launcher objects"
  (make-hash-table))

(defparameter *launchers* ;"Holds launchable launcher objects"
  (make-hash-table :test #'equal))

(defparameter *unknown-launchers* ;"Holds names and forms of unrecognized forms"
  (make-hash-table :test #'equal))

(defvar *store-initialized* nil
  "Set to T by INITIALIZE-LAUNCHER, cleared by UNINITIALIZE-LAUNCHER.
   WRITE-ALL-STORES refuses to rewrite on-disk stores while this is NIL,
   so an uninitialized image can never truncate a store to NIL.")

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

(defun store-key (path)
  "Normalize PATH (pathname or string) to a truename namestring for use as a
   hash key, so provenance recorded as a namestring and structural forms
   keyed by pathname compare equal.  Falls back to the plain namestring
   when the file does not exist."
  (when path
    (let ((probe (probe-file path)))
      (namestring (or probe path)))))

(defun read-store-forms (filepath)
  "Return the top-level list of forms in FILEPATH, or NIL when it does not
   exist.  Signals an error when an existing store cannot be read, so callers
   never overwrite a store whose contents they do not know."
  (when (probe-file filepath)
    (handler-case
        (let ((*package* (find-package :game-launcher))
              (*read-eval* nil))
          (with-open-file (stream filepath :direction :input)
            (read stream nil '())))
      (error (e)
        (error "Refusing to overwrite ~A: cannot read it (~A)" filepath e)))))

(defun same-form-multiset-p (a b)
  "Return true when A and B contain the same forms with the same
   multiplicities, ignoring order."
  (and (= (length a) (length b))
       (let ((remaining (make-hash-table :test #'equal)))
         (dolist (form a) (incf (gethash form remaining 0)))
         (loop for form in b
               for count = (gethash form remaining 0)
               always (plusp count)
               do (decf (gethash form remaining))))))

(defun structural-forms-of (forms)
  "Return the :store-file / :store-tree forms among FORMS."
  (loop for form in forms
        when (and (consp form)
                  (member (car form) '(:store-file :store-tree)))
          collect form))

(defun existing-structural-forms (filepath)
  "Return the :store-file / :store-tree forms already present in FILEPATH.
   Refuses to overwrite a store that cannot be read, rather than dropping
   its references.  Returns NIL for a missing or empty file."
  (structural-forms-of (read-store-forms filepath)))

(defun write-launchers-to-file (filepath &key source include-orphans)
  "Atomically write launcher forms to FILEPATH, keeping a .bak of any
   previous store.  Creates the containing directory as needed.  When
   SOURCE is given, only launcher/unknown definitions whose provenance is
   SOURCE are written back (so each store file keeps only its own
   definitions).  Structural forms recorded for SOURCE are appended; when no
   structural forms are recorded for SOURCE, the ones already present in
   FILEPATH are preserved instead.  Without SOURCE, all launchers are
   written but FILEPATH's own structural forms are still preserved.
   When INCLUDE-ORPHANS is true, launcher/unknown definitions with no
   recorded provenance are also written (used for the primary store).
   The file is left untouched (and no backup is made) when it already
   contains the same forms, ignoring order.
   Throws an error rather than overwriting a FILEPATH that cannot be read."
  (ensure-directories-exist filepath)
  (let* ((src-key (and source (store-key source)))
         (provenance-matches-p (lambda (name table)
                                 (let ((p (gethash name table)))
                                   (and p (equal (store-key p) src-key)))))
         (launchers (loop for launcher being the hash-values of *launchers*
                          when (cond
                                 (include-orphans (or (null (gethash (launcher-name launcher) *launcher-provenance*))
                                                    (funcall provenance-matches-p (launcher-name launcher) *launcher-provenance*)))
                                 ((not source) t)
                                 (t (funcall provenance-matches-p (launcher-name launcher) *launcher-provenance*)))
                          collect (launcher->form launcher)))
         (unknown-launchers (loop for unknown being the hash-values of *unknown-launchers*
                                  when (cond
                                         (include-orphans (or (null (gethash (form-name unknown) *unknown-provenance*))
                                                            (funcall provenance-matches-p (form-name unknown) *unknown-provenance*)))
                                         ((not source) t)
                                         (t (funcall provenance-matches-p (form-name unknown) *unknown-provenance*)))
                                  collect (form-data unknown)))
         (existing-forms (read-store-forms filepath))
         (structural-forms (if source
                               (or (gethash src-key *store-structural-forms*)
                                   (structural-forms-of existing-forms))
                               (structural-forms-of existing-forms)))
         (forms (append launchers unknown-launchers structural-forms))
         (backup (make-pathname :type "bak" :defaults filepath))
         (tmp (make-pathname :name (format nil "~A.tmp" (or (pathname-name filepath) "store"))
                             :type (pathname-type filepath)
                             :defaults filepath)))
    (unless (same-form-multiset-p existing-forms forms)
      (when (probe-file filepath)
        (uiop:copy-file filepath backup))
      (with-open-file (stream tmp
                              :direction :output
                              :if-exists :supersede
                              :if-does-not-exist :create)
        (pprint forms stream))
      (rename-file tmp filepath))))

(defun write-all-stores ()
  "Write each store file back with only the launcher/unknown definitions
   that originated from it.  The primary store path keeps everything with
   no recorded provenance.  Refuses to rewrite anything when the launcher
   state was never initialized in this image."
  (unless *store-initialized*
    (warn "Store not initialized; refusing to rewrite stores from an empty image")
    (return-from write-all-stores nil))
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
        (if source
          (setf (gethash (launcher-name launcher) *launcher-provenance*)
		(namestring source)) ;; set to source
	  (setf (gethash (launcher-name launcher) *launcher-provenance*)
		(namestring (store-path)))) ;; set to default
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
         (*read-eval* nil) ; never evaluate #. in a store file
         (base-dir (or base-dir (pathname-directory-pathname (truename filepath))))
         (key (store-key filepath)))
    (with-open-file (stream filepath :direction :input)
      (let ((forms (handler-case (read stream nil '())
                     (error (e)
                       (warn "Skipping unreadable store ~A: ~A" filepath e)
                       '())))) ; don't die on an empty or broken store file
        (dolist (form forms)
          (cond
            ((and (consp form) (eq (car form) :store-file))
             (dolist (p (cdr form))
               (add-store-entry p base-dir))
             (push form (gethash key *store-structural-forms*)))
            ((and (consp form) (eq (car form) :store-tree))
             (dolist (p (cdr form))
               (let ((resolved (probe-file (merge-pathnames p base-dir))))
                 (when resolved (read-tree-file resolved))))
             (push form (gethash key *store-structural-forms*)))
            (t
             (read-launcher form :source (store-key filepath)))))))))

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
		 ((and (consp form) (eq (car form) :store-tree))
		  (dolist (p (cdr form))
		    (when-let ((resolved (probe-file (merge-pathnames p base))))
			      (read-tree-file resolved))))
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
  (uninitialize-launcher) ;; clear before setting
  (read-profiles-from-file (env-profile-config-path))
  (read-store-tree)
  (load-all-stores)
  (setf *store-initialized* t))

(defun end-launcher ()
  "Writes profiles and stores, then uninitializes. When the launcher
   state was never initialized in this image, writes are skipped so
   on-disk data is left untouched."
  (if *store-initialized*
      (progn
        (write-all-stores)
        (write-profiles-to-file (env-profile-config-path)))
      (warn "Launcher was never initialized; leaving stores and profiles untouched"))
  (uninitialize-launcher))

(defun uninitialize-launcher ()
  "only clears launchers hash, use end-launcher to write & uninitialize"
  (clrhash *launchers*)
  (clrhash *unknown-launchers*)
  (clrhash *launcher-provenance*)
  (clrhash *unknown-provenance*)
  (clrhash *store-structural-forms*)
  (setf *store-path-list* nil
        *store-initialized* nil))

(defmacro with-launcher-session (() &body body)
  `(unwind-protect
        (progn
          (initialize-launcher)
          ,@body)
     (end-launcher)))
