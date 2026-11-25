## Add a runtime

Runtimes are files, not ASDF components of the core system. Create a directory
under any registered runtime root:

```text
~/.local/share/game-launcher/runtimes/my-runtime/runtime.lisp
```

Register the root for the current image:

```common-lisp
(game-launcher:runtime-path
 :path "~/.local/share/game-launcher/runtimes/" :add t)
```

or set `GAME_LAUNCHER_RUNTIMES` before starting.

### 1. Define the launcher class

```common-lisp
(in-package #:game-launcher)

(use-package :game-launcher)

(defclass my-launcher (launcher)
  ((args :initarg :args :accessor launcher-args)))
```

Keep runtime-specific state in slots. The base class already provides `name`,
`exec`, `profile`, `phases`, `tags`, `process`, and `lock`.

### 2. Implement the exec phase

```common-lisp
(defun my-exec-phase (ctx)
  (let ((process
          (sb-ext:run-program
           "my-runner"
           (cons (getf ctx :exec) (split-shell-args (getf ctx :args)))
           :environment (getf ctx :env)
           :directory (pathname-directory-pathname
                       (uiop:parse-native-namestring (getf ctx :exec)))
           :search t
           :input nil
           :output (or (getf ctx :log-path) *standard-output*)
           :error (or (getf ctx :log-path) *error-output*)
           :wait nil)))
    (note-process ctx process)
    (sb-ext:process-wait process)
    ctx))
```

Return the context. If the process should be tracked for `--stop`, call
`note-process`. If the runtime hands off to a daemon and cannot track it, skip
`note-process` and disable logging with `(standard-ctx l :log nil)`, as the
Steam and browser runtimes do.

### 3. Describe the pipeline

```common-lisp
(defparameter *my-pipeline*
  '((pre  . nil)
    (exec . my-exec-phase)
    (post . nil)
    (teardown . teardown-processes)))

(define-standard-pipeline-launch my-launcher *my-pipeline*)
```

`define-standard-pipeline-launch` expands to a `launch` method that applies
the launcher’s `:PHASES` clauses and uses `standard-ctx`. Define `launch`
yourself when the context needs extra keys.

### 4. Register the runtime

```common-lisp
(defun make-my-launcher (&key name exec args profile phases tags)
  (make-instance 'my-launcher
                 :name name
                 :exec exec
                 :args args
                 :profile profile
                 :phases phases
                 :tags tags))

(define-launcher-runtime my-runtime my-launcher make-my-launcher)
```

The runtime symbol must be reachable when a store is read. Store files are read
in the `GAME-LAUNCHER` package, so either define the runtime symbol in that
package or import/export it:

```common-lisp
(export-runtime-symbol-into-core 'my-runtime)
```

After that, this works:

```common-lisp
(MY-RUNTIME :NAME "Example" :EXEC "/home/me/example")
```

## Persist runtime-specific fields

The base `launcher->form` writes name, exec, phases, tags, and profile.
Subclasses append their own fields:

```common-lisp
(defmethod launcher->form ((launcher my-launcher))
  (append (call-next-method)
          (when (launcher-args launcher)
            `(:args ,(launcher-args launcher)))))
```

Without this method, runtime-specific slots are lost on the next store write.

## Custom logging

Override `resolve-launcher-log` to change where output goes:

```common-lisp
(defmethod resolve-launcher-log ((launcher my-launcher))
  (open (merge-pathnames "my-launcher.log"
                         (uiop:xdg-data-home "game-launcher/"))
        :direction :output
        :if-exists :append
        :if-does-not-exist :create))
```

The default implementation writes one unique log per launch under
`~/.local/share/game-launcher/` and maintains a `current-…` symlink.

## Add an importer

An importer is an ordinary ASDF system that depends on `game-launcher` plus
whatever it needs:

```common-lisp
(defsystem "game-launcher.my-import"
  :depends-on ("game-launcher" "my-parser")
  :components ((:file "my-import")))
```

Inside, parse the external data and register launchers:

```common-lisp
(defun import-my-game (source)
  (let ((launcher (make-launcher 'exec
                                 :name (my-name source)
                                 :exec (my-executable source))))
    (register-launcher-instance launcher)
    launcher))
```

Registering is enough for persistence; provenance handling and store writing
are the core’s job. Add an `--import` branch in the Roswell CLI if you want a
command-line entry point.

## Useful extension points

| Symbol | Use |
| --- | --- |
| `register-launcher` | Map a runtime symbol to a constructor without the macro. |
| `register-launcher-instance` | Add or replace a launcher in the live registry. |
| `runtime-path` / `runtime-paths` | Add or inspect runtime roots. |
| `store-path` / `store-paths` | Add or inspect stores. |
| `load-runtime` / `reload-runtime` | Control lazy runtime loading. |
| `launcher->form` | Add fields to the persisted representation. |
| `resolve-launcher-log` | Replace log creation. |
| `make-launcher` | Construct a launcher and resolve profiles/markers. |
