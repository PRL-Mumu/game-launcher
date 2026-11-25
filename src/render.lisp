(in-package #:game-launcher-docs)

(defun markdown->html (text)
  "Render TEXT (Markdown) to HTML with fenced code blocks and tables."
  (with-output-to-string (out)
    (let ((3bmd:*smart-quotes* nil)
          (3bmd:*generate-header-ids* t)
          (3bmd-code-blocks:*code-blocks* t)
          (3bmd-code-blocks:*renderer* :nohighlight)
          (3bmd-code-blocks:*code-blocks-pre-class-format* "language-~a")
          (3bmd-tables:*tables* t))
      (3bmd:parse-string-and-print-to-stream text out))))

(defun render-sidebar (current-page)
  (spinneret:with-html
    (:aside :class "sidebar" :id "sidebar"
      (:div :class "sidebar-brand"
        (:a :class "brand" :href "index.html"
          (:span :class "brand-mark" "GL")
          (:span :class "brand-copy"
            (:span :class "brand-name" *site-title*)
            (:span :class "brand-tagline" *site-tagline*))))
      (:nav :class "sidebar-nav" :aria-label "Guide navigation"
        (dolist (group (grouped-pages))
          (:div :class "nav-group"
            (:p :class "nav-heading" (car group))
            (:ul
              (dolist (page (cdr group))
                (let ((active (eq page current-page)))
                  (:li
                    (:a :class (if active "nav-link is-active" "nav-link")
                        :href (page-url page)
                        :aria-current (if active "page" nil)
                        (getf page :title)))))))))
      (:div :class "sidebar-foot"
        (:span (format nil "v~A" *site-version*))
        (:a :href *repo-url* :target "_blank" :rel "noopener noreferrer"
          *repo-label*)))))

(defun render-topbar (page)
  (spinneret:with-html
    (:div :class "topbar"
      (:button :class "icon-button menu-button" :type "button"
               :id "menu-toggle" :aria-label "Toggle navigation"
               :aria-controls "sidebar" :aria-expanded "false"
        (:span :class "menu-lines" (:span) (:span) (:span)))
      (:div :class "crumbs"
        (:span :class "crumb-group" (getf page :group))
        (:span :class "crumb-sep" "/")
        (:span :class "crumb-current" (getf page :title)))
      (:div :class "topbar-actions"
        (:a :class "text-link" :href *repo-url*
            :target "_blank" :rel "noopener noreferrer"
          *repo-label*)
        (:button :class "icon-button theme-button" :type "button"
                 :id "theme-toggle" :aria-label "Toggle dark mode"
          (:span :class "theme-icon theme-icon-light" "☀")
          (:span :class "theme-icon theme-icon-dark" "☾"))))))

(defun render-pager (page)
  (multiple-value-bind (previous next) (page-neighbours page)
    (when (or previous next)
      (spinneret:with-html
        (:nav :class "pager" :aria-label "Previous and next pages"
          (if previous
              (:a :class "pager-link pager-prev" :href (page-url previous)
                (:span :class "pager-label" "Previous")
                (:span :class "pager-title" (getf previous :title)))
              (:span :class "pager-spacer"))
          (if next
              (:a :class "pager-link pager-next" :href (page-url next)
                (:span :class "pager-label" "Next")
                (:span :class "pager-title" (getf next :title)))
              (:span :class "pager-spacer")))))))

(defun render-page (page body-html)
  "Wrap rendered BODY-HTML in the shared documentation layout."
  (spinneret:with-html-string
    (:doctype)
    (:html :lang "en"
      (:head
        (:meta :charset "utf-8")
        (:meta :name "viewport" :content "width=device-width, initial-scale=1")
        (:title (format nil "~A · ~A" (getf page :title) *site-title*))
        (:meta :name "description" :content (getf page :description))
        (:link :rel "icon" :href "assets/favicon.svg" :type "image/svg+xml")
        (:script
          "try{var c=document.cookie.match('(?:^|; )gl-theme=([^;]*)');var t=c?c[1]:null;if(t){document.documentElement.dataset.theme=t}else if(window.matchMedia('(prefers-color-scheme: dark)').matches){document.documentElement.dataset.theme='dark'}}catch(e){}")
        (:link :rel "stylesheet" :href "assets/style.css")))
      (:body :class (format nil "page-~A" (getf page :slug))
        (:a :class "skip-link" :href "#content" "Skip to content")
        (:div :class "layout"
          (render-sidebar page)
          (:div :class "main-column"
            (render-topbar page)
            (:main :class "content" :id "content"
              (:article :class "prose"
                (:header :class "page-header"
                  (:p :class "eyebrow" (getf page :group))
                  (:h1 (getf page :title))
                  (:p :class "lede" (getf page :description)))
                (:div :class "markdown" (:raw body-html))
                (render-pager page)))
            (:footer :class "site-foot"
              (:p
                (:span (format nil "~A guide" *site-title*))
                (:span :class "dot" "·")
                (:a :href *repo-url* :target "_blank" :rel "noopener noreferrer"
                  "Source on GitHub")
                (:span :class "dot" "·")
                (:span (format nil "v~A" *site-version*))))))
        (:script :src "assets/app.js"))))
