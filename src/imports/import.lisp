
(in-package :game-launcher)

(defun import-launcher-form (form)
  (let ((*package* (find-package :game-launcher)))
    (handler-case
        (register-launcher-instance
         (apply #'make-launcher form))
      (unknown-runtime ()
        (register-unknown-launcher
         (save-unknown-form form)))
      (error (e)
        (warn "Could not import launcher ~S: ~A" form e)))))

					; (defun import-launcher-desktop (path)
					;   (format t "importing from desktop path"))

(defun parse-desktop-file (path)
  "Parse a .desktop file and return a property list"
  (let ((name nil)
        (exec nil)
        (path-dir nil))
    (with-open-file (stream path :direction :input)
      (loop for line = (read-line stream nil)
            while line
            do (cond ((and (not name) (cl-ppcre:scan "^Name=" line))
                      (setf name (subseq line 5)))
                     ((and (not exec) (cl-ppcre:scan "^Exec=" line))
                      (setf exec (subseq line 5)))
                     ((and (not path-dir) (cl-ppcre:scan "^Path=" line))
                      (setf path-dir (subseq line 5))))))
    (list :name name :exec exec :working-directory path-dir)))

(defun import-desktop-file (path)
  "Import a game from a .desktop file"
  (let ((data (parse-desktop-file path)))
    (when (and (getf data :name) (getf data :exec))
      (register-launcher-instance
       (let ((exec (uiop:split-string (getf data :exec))))
	 (make-launcher 'exec
			:name (getf data :name)
			:exec (first exec)
			:args (rest exec)))))))

;; STEAM

(defun steam-app-id-p (string)
  "Return T if STRING contains only decimal digits."
  (and (plusp (length string))
       (every #'digit-char-p string)))

(defun assoc-path (alist path &key (key #'identity) (test #'eql) (default nil))
  "Retrieve the value in the given ALIST represented by the given PATH"
  (or (reduce (lambda (alist k)
                (cdr (assoc k alist :key key :test test)))
              path
              :initial-value alist)
      default))

(defun steam-app-id-from-url (url)
  "Extract a Steam App ID from a store or launch URL."
  (cond
    ;; https://store.steampowered.com/app/251150/...
    ((uiop:string-prefix-p
      "https://store.steampowered.com/app/"
      url)
     (let ((rest (subseq url
                         (length "https://store.steampowered.com/app/"))))
       (parse-integer rest :junk-allowed t)))

    ;; steam://rungameid/251150
    ((uiop:string-prefix-p "steam://rungameid/" url)
     (parse-integer
      (subseq url (length "steam://rungameid/"))
      :junk-allowed t))

    ;; steam://run/251150
    ((uiop:string-prefix-p "steam://run/" url)
     (parse-integer
      (subseq url (length "steam://run/"))
      :junk-allowed t))

    (t nil)))

(defun steam-app-name (app-id)
  (let* ((url (format nil
                      "https://store.steampowered.com/api/appdetails?appids=~D"
                      app-id))
         (json-data
           (cl-json:decode-json-from-string
            (dexador:get url))))
    (assoc-path json-data
                (list (intern (princ-to-string app-id) :keyword)
                      :data
                      :name))))

(defun import-steam-id (id)
  "Import a game from a Steam App ID, store URL, or launch URL."
  (let ((app-id
          (cond
            ;; 251150
            ((steam-app-id-p id)
             (parse-integer id))
            ;; https://store.steampowered.com/app/251150/...
            ;; steam://rungameid/251150
            ((steam-app-id-from-url id))

            (t nil))))
    (if app-id
	(register-launcher-instance
	 (make-launcher 'steam
			:name (steam-app-name app-id)
			:exec (format nil "steam://rungameid/~D" app-id)))
        (warn "Could not determine Steam App ID from ~S" id))))

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

(defun import-lutris (db-path)
  (dolist (game (parse-lutris-database db-path))
    (let ((yaml-path (lutris-yaml-path game)))
      (when (probe-file yaml-path)
        (import-lutris-game
         game
         (parse-lutris-yaml yaml-path))))))

(defun import-lutris-game (id))
