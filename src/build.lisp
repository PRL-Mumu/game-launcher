(in-package #:game-launcher-docs)

(defun read-text-file (path)
  (with-open-file (stream path :direction :input :external-format :utf-8)
    (let ((text (make-string (file-length stream))))
      (subseq text 0 (read-sequence text stream)))))

(defun write-text-file (path text)
  (ensure-directories-exist path)
  (with-open-file (stream path :direction :output
                               :if-exists :supersede
                               :if-does-not-exist :create
                               :external-format :utf-8)
    (write-string text stream))
  path)

(defun copy-static-assets (output-directory)
  (let ((assets (merge-pathnames "assets/" output-directory)))
    (ensure-directories-exist assets)
    (dolist (file (uiop:directory-files (static-directory)))
      (uiop:copy-file file (merge-pathnames (file-namestring file) assets)))))

(defun build-site (&key output-directory)
  "Render every page in *PAGES* from content/SLUG.md into OUTPUT-DIRECTORY.
Returns the output directory."
  (let ((*site-output-directory* (or output-directory *site-output-directory*))
        (output (or output-directory (site-directory))))
    (ensure-directories-exist output)
    (copy-static-assets output)
    (dolist (page *pages*)
      (let ((source (page-content-path page)))
        (unless (probe-file source)
          (error "Missing content file for page ~A: ~A"
                 (getf page :slug) source))
        (let* ((markdown (read-text-file source))
               (body (markdown->html markdown))
               (html (render-page page body))
               (target (merge-pathnames (page-url page) output)))
          (write-text-file target html)
          (format t "  ~A -> ~A~%" (file-namestring source) (file-namestring target)))))
    (write-text-file (merge-pathnames ".nojekyll" output) "")
    (format t "~&Built ~D pages in ~A~%" (length *pages*) output)
    output))

(defvar *acceptor* nil)

(defun start-server (&key (port *default-port*) (address *default-address*) build)
  "Start a Hunchentoot server for the generated site.  When BUILD is true
rebuild the site first.  Returns the acceptor."
  (when build
    (build-site))
  (when (and *acceptor* (hunchentoot:started-p *acceptor*))
    (hunchentoot:stop *acceptor*))
  (setf *acceptor*
        (make-instance 'hunchentoot:easy-acceptor
                       :port port
                       :address address
                       :document-root (namestring (site-directory))
                       :access-log-destination nil
                       :message-log-destination nil))
  (hunchentoot:start *acceptor*)
  (format t "~&Serving ~A at http://~A:~D/~%"
          (site-directory) address port)
  (finish-output)
  *acceptor*)

(defun stop-server ()
  "Stop the preview server started by START-SERVER, if any."
  (when (and *acceptor* (hunchentoot:started-p *acceptor*))
    (hunchentoot:stop *acceptor*))
  (setf *acceptor* nil))

(defun serve-site (&key (port *default-port*) (address *default-address*) (build t))
  "Build the site and serve it until interrupted."
  (start-server :port port :address address :build build)
  (handler-case
      (loop (sleep 3600))
    (sb-sys:interactive-interrupt ()
      (stop-server)
      (format t "~&Stopped preview server.~%"))))
