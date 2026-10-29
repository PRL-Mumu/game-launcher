(in-package :game-launcher.steam)

(use-package :game-launcher)

(defun steam-app-id-p (string)
  "Return T if STRING contains only decimal digits."
  (and (plusp (length string))
       (every #'digit-char-p string)))


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

    ;; steamdb

    ;; https://steamdb.info/app/2161700/
    ((uiop:string-prefix-p "https://steamdb.info/app/" url)
     (parse-integer
       (subseq url (length "https://steamdb.info/app/"))
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
  (let* ((app-id
	   (cond
	     ;; 251150
	     ((steam-app-id-p id)
	      (parse-integer id))
	     ;; https://store.steampowered.com/app/251150/...
	     ;; steam://rungameid/251150
	     ((steam-app-id-from-url id))

	     (t nil)))
	 )
    (if app-id
      (register-launcher-instance
	(game-launcher::make-steam-launcher
	 :name (steam-app-name app-id)
	 :profile (game-launcher::env)
	 :exec (format nil "steam://rungameid/~D" app-id)))
      (warn "Could not determine Steam App ID from ~S" id))))

(defparameter +steam-import-blacklist+
  (list "3648110" "1070560" "1391110" "1493710" "1628350" "2180100"
	"228980" "3029110" "3658110" "4183110" "4628710"))

(defun steam-local-import (steam-id path)
  (if (member steam-id +steam-import-blacklist+ :test #'string=)
      (format t "skipping blacklisted id: ~A~%" steam-id)
      (let* ((manifest (uiop:subpathname*
                        (uiop:ensure-directory-pathname path)
                        (format nil "steamapps/appmanifest_~A.acf" steam-id)))
             (app-name (acf-ref (parse-acf manifest) "AppState" "name")))
        (register-launcher-instance
         (game-launcher::make-steam-launcher
          :name app-name
          :profile (game-launcher::env)
          :exec (format nil "steam://rungameid/~D" steam-id))))))

(defun steam-local-import-all ()
  (let* ((vdf (parse-acf (uiop:xdg-data-home "Steam/steamapps/libraryfolders.vdf")))
       (folders (acf-ref vdf "libraryfolders")))
  (loop for (index . entry) in folders
        when (every #'digit-char-p index)
        do (let* ((root (acf-ref entry "path"))
                  (apps (acf-ref entry "apps")))
             (loop for steam-id in (mapcar #'car apps)
                   do (steam-local-import steam-id root))))))
