
(in-package :game-launcher)

(defstruct lutris-game
  id
  name
  slug
  platform
  runner
  executable
  directory
  configpath
  installed)

(defun yaml-env->profile (yaml)
  (let* ((game (yaml-get yaml "game"))
         (prefix (yaml-get game "prefix")))
    (make-profile
     (append (env-table->alist (yaml-get (yaml-get yaml "system") "env"))
             (env-table->alist (yaml-get game "env"))
             (when prefix
               (list (list "WINEPREFIX" (scalar->string prefix))))))))

(defun yaml-get (table key)
  (when table
    (loop for k being the hash-keys of table
          when (string-equal k key)
            return (values (gethash k table)))))

(defun env-table->alist (tbl)
  (when tbl
    (loop for k being the hash-keys of tbl
          for v being the hash-values of tbl
          collect (list (princ-to-string k) (scalar->string v)))))

(defun row-get (row column)
  ;; column is a plain string like "name"; DBI keywords are lowercase
  (getf row (intern (string-downcase column) :keyword)))

(defun clean (v) (if (or (eq v :null) (equal v "")) nil v))

(defun row->lutris-game (row)
  (flet ((col (c) (clean (row-get row c))))
    (make-lutris-game
     :id         (row-get row "id")
     :name       (col "name")
     :slug       (col "slug")
     :platform   (col "platform")
     :runner     (col "runner")
     :directory  (col "directory")
     :configpath (col "configpath")
     :executable (col "executable")
     :installed  (not (zerop (row-get row "installed"))))))


(defun lutris-yaml-config-path (configpath)
  (loop for base in (list (uiop:xdg-data-home)
                          (uiop:xdg-config-home))
        for p = (merge-pathnames
                 (format nil "lutris/games/~A.yml" configpath)
                 base)
        when (probe-file p)
          return p))

(defun lutris-db-config-path ()
  (loop for base in (list (uiop:xdg-data-home)
                          (uiop:xdg-config-home))
        for p = (merge-pathnames
                 (format nil "lutris/pga.db")
                 base)
        when (probe-file p)
          return p))

(defparameter *lutris-columns*
  '(id name slug platform runner directory configpath executable installed))

(defun lutris-select-sql ()
  (format nil "SELECT ~{~A~^, ~} FROM games WHERE installed = 1"
          *lutris-columns*))

(defun read-lutris-db (path)
  (dbi:with-connection (conn :sqlite3 :database-name (namestring path))
    (let* ((q (dbi:prepare conn (lutris-select-sql)))
           (res (dbi:execute q)))
      (loop for row = (dbi:fetch res)
            while row
            collect (row->lutris-game row)))))

(defun split-shell-args (string)
  "split a command-line-style string into argv elements;
   double/single quotes group, whitespace outside quotes separates"
  (let ((args '())
        (buf (make-array 0 :element-type 'character :fill-pointer 0 :adjustable t))
        (started nil)
        (quote nil))
    (flet ((flush ()
             (when started
               (push (copy-seq buf) args)
               (setf (fill-pointer buf) 0 started nil))))
      (loop for ch across string
            do (cond
                 ((and quote (char= ch quote))
                  (setf quote nil started t))
                 (quote
                  (vector-push-extend ch buf))
                 ((member ch '(#\" #\') :test #'char=)
                  (setf quote ch started t))
                 ((member ch '(#\space #\tab #\newline))
                  (flush))
                 (t
                  (vector-push-extend ch buf)
                  (setf started t))))
      (when quote (warn "unterminated quote in args: ~S" string))
      (flush))
    (nreverse args)))

(defun normalize-args (a)
  (typecase a
    (null   nil)
    (cons   (mapcar #'scalar->string a))  ; yaml list: elements are already separate argv items
    (string (split-shell-args a))         ; command-line syntax: parse it
    (t      (list (scalar->string a)))))  ; lone scalar

(defparameter *lutris-games* nil)

(defun load-lutris-games ()
  (setf *lutris-games* (read-lutris-db (lutris-db-config-path))))

(defun find-lutris-game (name)
  (find name *lutris-games* :key #'lutris-game-name :test #'string-equal))

(defun convert-lutris-game-struct (game)
  (let ((yaml-path (lutris-yaml-config-path (lutris-game-configpath game))))
    (if (and (string-equal (lutris-game-runner game) "wine") yaml-path)
        (let* ((yaml (cl-yaml:parse (uiop:read-file-string yaml-path)))
               (game-block (yaml-get yaml "game"))
               (exe (yaml-get game-block "exe")))
          (if exe
              (make-instance 'wine-launcher
                             :name (lutris-game-name game)
                             :exec (scalar->string exe)
                             :args (normalize-args (yaml-get game-block "args"))
                             :profile (yaml-env->profile yaml)
                             ;:lutris-id (lutris-game-id game)
			     )
              (warn "skipping ~A: wine game, no exe in yaml"
                    (lutris-game-name game))))
        (warn "skipping ~A: runner ~S not supported"
              (lutris-game-name game) (lutris-game-runner game)))))

(defun convert-lutris-game (name)
  (alexandria:if-let ((game (find-lutris-game name)))
    (convert-lutris-game-struct game)
    (warn "no lutris game named ~S" name)))


(defun import-lutris-game (name)
  (alexandria:if-let ((launcher (convert-lutris-game name)))
    (progn (register-launcher-instance launcher) launcher)
    (warn "could not import lutris game ~S" name)))

(defun import-all-lutris-games ()
  (load-lutris-games)
  (let (imported skipped failed)
    (dolist (game *lutris-games*)
      (handler-case
          (let ((l (convert-lutris-game-struct game)))
            (if l
                (progn (register-launcher-instance l) (push l imported))
                (push (lutris-game-name game) skipped)))
        (error (e)
          (push (lutris-game-name game) failed)
          (warn "failed to import ~A: ~A" (lutris-game-name game) e))))
    (format t "lutris import: ~D converted, ~D skipped, ~D failed~%"
            (length imported) (length skipped) (length failed))
    (values imported skipped failed)))
