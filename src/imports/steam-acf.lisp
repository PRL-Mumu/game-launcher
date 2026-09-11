;;;; steam-acf.lisp -- parser for Valve Steam ACF/VDF files
;;;
;;; No dependencies.  Returns nested alists, key order preserved:
;;;   "AppState" { "appid" "440" }   =>  (("AppState" ("appid" . "440")))
;;;
;;; Invariant: every value is either a STRING (scalar) or an ALIST (object);
;;; an empty {} block is represented as NIL.


;;;; Conditions ---------------------------------------------------------------

(in-package :game-launcher)

(define-condition acf-parse-error (error)
  ((message :initarg :message :reader acf-parse-error-message)
   (line    :initarg :line    :reader acf-parse-error-line)
   (column  :initarg :column  :reader acf-parse-error-column))
  (:report (lambda (c stream)
             (format stream "ACF parse error at ~a:~a: ~a"
                     (acf-parse-error-line c)
                     (acf-parse-error-column c)
                     (acf-parse-error-message c)))))

;;;; Tokenizer ----------------------------------------------------------------

(defstruct (token (:constructor token (type value line column)))
  type value line column)

(defparameter +whitespace+
  (list #\Space #\Tab #\Newline #\Return #\Linefeed #\Page
        (code-char #xFEFF))                  ; UTF-8 byte-order mark
  "Characters ignored between tokens.")

(defun whitespace-p (char)
  (member char +whitespace+ :test #'char=))

(defun tokenize (text)
  "Turn TEXT into a list of tokens: :string, :open-brace, :close-brace."
  (let ((tokens '())
        (i 0)
        (line 1)
        (column 1)
        (end (length text)))
    (labels ((peek ()
               (when (< i end) (char text i)))
             (advance ()
               (let ((ch (char text i)))
                 (incf i)
                 (if (char= ch #\Newline)
                     (setf line (1+ line) column 1)
                     (incf column))
                 ch))
             (syntax-error (format-control &rest args)
               (error 'acf-parse-error
                      :message (apply #'format nil format-control args)
                      :line line :column column))
             (read-string ()
               (let ((buf (make-array 32 :element-type 'character
                                         :adjustable t :fill-pointer 0)))
                 (advance)                          ; consume opening quote
                 (loop
                   (let ((ch (peek)))
                     (cond ((null ch) (syntax-error "unterminated string"))
                           ((char= ch #\")
                            (advance)
                            (return (coerce buf 'string)))
                           ((char= ch #\\)
                            (advance)
                            (let ((next (peek)))
                              (when (null next)
                                (syntax-error "unterminated string"))
                              (advance)
                              (vector-push-extend
                               (case next
                                 (#\n #\Newline)
                                 (#\r #\Return)
                                 (#\t #\Tab)
                                 (t next))          ; \" \\ and lenient fallback
                               buf)))
                           (t
                            (vector-push-extend (advance) buf))))))))
      (loop
        (loop while (let ((ch (peek))) (and ch (whitespace-p ch)))
              do (advance))
        (let ((ch (peek)))
          (cond ((null ch) (return (coerce (nreverse tokens) 'vector)))
                ((char= ch #\{)
                 (let ((l line) (c column))
                   (advance)
                   (push (token :open-brace nil l c) tokens)))
                ((char= ch #\})
                 (let ((l line) (c column))
                   (advance)
                   (push (token :close-brace nil l c) tokens)))
                ((char= ch #\")
                 (let ((l line) (c column))
                   (push (token :string (read-string) l c) tokens)))
                (t (syntax-error "unexpected character ~:c" ch))))))))

;;;; Parser -------------------------------------------------------------------

(defun token-description (tok)
  (cond ((null tok) "end of file")
        ((eq (token-type tok) :open-brace) "\"{\"")
        ((eq (token-type tok) :close-brace) "\"}\"")
        (t (format nil "string ~s" (token-value tok)))))

(defun parse-tokens (tokens)
  (let ((pos 0))
    (labels ((peek ()
               (when (< pos (length tokens)) (aref tokens pos)))
             (next ()
               (let ((tok (peek))) (incf pos) tok))
             (error-at (tok format-control &rest args)
               (error 'acf-parse-error
                      :message (apply #'format nil format-control args)
                      :line (if tok (token-line tok) 1)
                      :column (if tok (token-column tok) 1)))
             ;; Parse pairs until a '}' (consumed) when CLOSEP, else until EOF.
             (parse-object (closep)
               (let ((pairs '()))
                 (loop
                   (let ((tok (peek)))
                     (cond ((null tok)
                            (when closep
                              (error-at (and (plusp pos) (aref tokens (1- pos)))
                                        "unexpected end of file; missing \"}\""))
                            (return (nreverse pairs)))
                           ((eq (token-type tok) :close-brace)
                            (unless closep (error-at tok "unmatched \"}\""))
                            (next)
                            (return (nreverse pairs)))
                           (t (push (parse-pair) pairs)))))))
             (parse-pair ()
               (let ((key-tok (next)))
                 (unless (eq (token-type key-tok) :string)
                   (error-at key-tok "expected a key, got ~a"
                             (token-description key-tok)))
                 (let ((value-tok (peek)))
                   (cond ((null value-tok)
                          (error-at key-tok "missing value for key ~s"
                                    (token-value key-tok)))
                         ((eq (token-type value-tok) :open-brace)
                          (next)
                          (cons (token-value key-tok) (parse-object t)))
                         ((eq (token-type value-tok) :string)
                          (next)
                          (cons (token-value key-tok) (token-value value-tok)))
                         (t
                          (error-at value-tok
                                    "expected a value or \"{\" after key ~s, got ~a"
                                    (token-value key-tok)
                                    (token-description value-tok))))))))
      ;; Top level: either bare pairs (config.vdf style) or one "{ ... }" block.
      (let ((first (peek)))
        (if (and first (eq (token-type first) :open-brace))
            (progn (next) (parse-object t))
            (parse-object nil))))))

;;;; Public interface ---------------------------------------------------------

(defun slurp (input)
  "Read every character from INPUT (string, pathname, or stream)."
  (typecase input
    (string input)
    (pathname
     ;; Drop the :external-format argument if your Lisp doesn't support :utf-8.
     (with-open-file (in input :external-format :utf-8)
       (let ((text (make-array (max 32 (file-length in))
                               :element-type 'character
                               :adjustable t :fill-pointer 0)))
         (loop for ch = (read-char in nil nil)
               while ch do (vector-push-extend ch text))
         text)))
    (stream
     (let ((text (make-array 32 :element-type 'character
                                :adjustable t :fill-pointer 0)))
       (loop for ch = (read-char input nil nil)
             while ch do (vector-push-extend ch text))
       text))
    (t (error "Can't read ACF input from ~s" input))))

(defun parse-acf (input)
  "Parse Steam ACF/VDF data.  INPUT is a pathname, string, or stream.
Returns an alist: keys and scalar values are strings, nested objects are
further alists, an empty object is NIL.  Order is preserved; every value
stays a string exactly as it appears in the file."
  (parse-tokens (tokenize (slurp input))))

(defun acf-get (key object &optional default)
  "Look up KEY (a string) in OBJECT, an alist from PARSE-ACF.
Returns two values: the value and a presence flag."
  (let ((pair (assoc key object :test #'string=)))
    (if pair (values (cdr pair) t) (values default nil))))

(defun acf-ref (object &rest keys)
  "Traverse nested objects: (acf-ref m \"AppState\" \"name\")."
  (reduce (lambda (obj key) (if (consp obj) (acf-get key obj)))
          keys :initial-value object))

(defun acf->hash (object)
  "Recursively convert an ACF alist into nested hash tables (EQUAL keys)."
  (let ((table (make-hash-table :test 'equal)))
    (loop for (key . value) in object
          do (setf (gethash key table)
                   (if (listp value) (acf->hash value) value)))
    table))

;;;; Writer (handy for round-trip testing) ------------------------------------

(defun acf-escape (string)
  (with-output-to-string (out)
    (write-char #\" out)
    (loop for ch across string
          do (case ch
               (#\\ (write-string "\\\\" out))
               (#\" (write-string "\\\"" out))
               (#\Newline (write-string "\\n" out))
               (#\Tab (write-string "\\t" out))
               (t (write-char ch out))))
    (write-char #\" out)))

(defun write-acf (object &optional (stream *standard-output*))
  "Serialize an ACF alist back out in ACF format."
  (labels ((write-object (obj depth)
             (loop for (key . value) in obj
                   do (dotimes (n depth) (write-char #\Tab stream))
                      (write-string (acf-escape key) stream)
                      (if (listp value)
                          (progn (terpri stream)
                                 (dotimes (n depth) (write-char #\Tab stream))
				 (write-line "{" stream)
                                 (write-object value (1+ depth))
                                 (dotimes (n depth) (write-char #\Tab stream))
                                 (write-line "}" stream))
                          (progn (write-char #\Tab stream)
                                 (write-string (acf-escape value) stream)
                                 (terpri stream))))))
    (write-object object 0)
    object))
