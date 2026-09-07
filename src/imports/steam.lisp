
(in-package :game-launcher)

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

    (t nil)))

(defun steam-app-name (app-id)
  (print "Contacting steam for name")
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
