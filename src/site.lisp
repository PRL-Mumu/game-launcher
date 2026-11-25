(in-package #:game-launcher-docs)

(defparameter *site-title* "game-launcher")
(defparameter *site-tagline* "Guide")
(defparameter *site-description*
  "A practical guide to game-launcher, a Common Lisp framework for describing and launching games.")
(defparameter *site-version* "0.5.0")
(defparameter *repo-url* "https://github.com/PRL-Mumu/game-launcher")
(defparameter *repo-label* "GitHub")
(defparameter *default-port* 4173)
(defparameter *default-address* "127.0.0.1")

(defparameter *page-groups*
  '("Start here"
    "Core concepts"
    "Guides"
    "Reference"))

(defparameter *pages*
  '((:slug "index"
     :title "Overview"
     :description "What game-launcher is, what it is not, and how the pieces fit together."
     :group "Start here")
    (:slug "getting-started"
     :title "Getting started"
     :description "Install game-launcher, point it at a store, and launch your first game."
     :group "Start here")
    (:slug "cli"
     :title "Command line"
     :description "Every command, what it does, and how session tracking works."
     :group "Start here")
    (:slug "store"
     :title "Store files"
     :description "Describe games as Lisp data, split stores into trees, and understand how writes work."
     :group "Core concepts")
    (:slug "profiles"
     :title "Profiles & environment"
     :description "Share environment variables between launchers with named and inline profiles."
     :group "Core concepts")
    (:slug "runtimes"
     :title "Runtimes"
     :description "How launch backends are discovered, registered, and selected."
     :group "Core concepts")
    (:slug "phases"
     :title "Launch phases"
     :description "Insert, replace, and remove steps in a launch pipeline."
     :group "Core concepts")
    (:slug "importing"
     :title "Importing games"
     :description "Bring in desktop entries, Lutris games, and Steam libraries."
     :group "Guides")
    (:slug "extending"
     :title "Extending game-launcher"
     :description "Add a runtime, a launcher subclass, or a whole import backend."
     :group "Guides")
    (:slug "library"
     :title "Using it as a library"
     :description "Drive the registry and launch API directly from Common Lisp."
     :group "Guides")
    (:slug "api"
     :title "API reference"
     :description "The public symbols exported by the GAME-LAUNCHER package."
     :group "Reference")
    (:slug "architecture"
     :title "Architecture"
     :description "How the registry, provenance tracking, runtime loading, and store writer fit together."
     :group "Reference")))

(defun project-root ()
  "Directory containing this ASDF system."
  (asdf:system-source-directory :game-launcher-docs))

(defun content-directory ()
  (merge-pathnames "content/" (project-root)))

(defun static-directory ()
  (merge-pathnames "static/" (project-root)))

(defvar *site-output-directory* nil
  "When non-NIL, write the generated site here instead of ./docs/.")

(defun site-directory ()
  (or *site-output-directory*
      (merge-pathnames "docs/" (project-root))))

(defun page-by-slug (slug)
  (find slug *pages* :key (lambda (page) (getf page :slug)) :test #'string=))

(defun page-url (page)
  (format nil "~A.html" (getf page :slug)))

(defun page-content-path (page)
  (merge-pathnames (format nil "~A.md" (getf page :slug)) (content-directory)))

(defun grouped-pages ()
  "Return *PAGES* grouped into (GROUP . PAGES) pairs, in display order."
  (loop for group in *page-groups*
        for pages = (remove-if-not (lambda (page) (string= group (getf page :group)))
                                   *pages*)
        when pages
          collect (cons group pages)))

(defun page-neighbours (page)
  "Return (VALUES PREVIOUS NEXT) for PAGE in flat navigation order."
  (let* ((flat (loop for (nil . pages) in (grouped-pages) append pages))
         (position (position page flat)))
    (values (and position (> position 0) (nth (1- position) flat))
            (and position (< position (1- (length flat))) (nth (1+ position) flat)))))
