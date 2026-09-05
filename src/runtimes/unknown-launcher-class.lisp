(in-package #:game-launcher)

(defclass unknown-launcher ()
  ((name
    :initarg :name
    :accessor form-name)
   (form
    :initarg :data
    :accessor form-data)))
