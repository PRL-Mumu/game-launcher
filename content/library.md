## Load the system

```common-lisp
(ql:quickload :game-launcher)
```

The core package is `GAME-LAUNCHER`. It exports the launcher class, the
registry functions, store/runtime path helpers, and the launch API. Runtime
classes and runtime-specific constructors live in the same package once their
`runtime.lisp` files are loaded.

## Sessions

The normal entry point is `with-launcher-session`:

```common-lisp
(game-launcher:with-launcher-session ()
  (game-launcher:display-launchers (game-launcher:launcher-list)))
```

It calls `initialize-launcher`, runs the body, then `end-launcher`. The end
step writes profiles and every store back, then clears the in-memory registry.
Use it whenever changes should persist.

The lower-level pair is available too:

```common-lisp
(game-launcher:initialize-launcher)
(unwind-protect
     (progn ...)
  (game-launcher:end-launcher))
```

`end-launcher` refuses to write if the image was never initialized, so calling
it by mistake cannot truncate a store to an empty file.

## Create and launch

```common-lisp
(game-launcher:with-launcher-session ()
  (let ((launcher
          (game-launcher:make-launcher
           'exec
           :name "Cataclysm Bright Nights"
           :exec "/home/me/Games/cataclysmbn-v0.12.0/cataclysm-launcher")))
    (game-launcher:register-launcher-instance launcher)
    (game-launcher:launch launcher)))
```

`make-launcher` takes a runtime symbol followed by initargs. It loads the
runtime first, resolves inline or named profiles, handles `=>NAME` markers, and
signals `unknown-runtime` if no constructor exists.

`launch` is synchronous: it runs the pipeline and returns when the pipeline
finishes. Runtime exec phases generally wait for the game process, so this may
be a long call. For a non-blocking launch, start your own thread or use the
exported `run-launcher-thread`, which catches and reports errors.

## Find launchers

```common-lisp
(game-launcher:launcher-names)                  ; all names
(game-launcher:launcher-list)                   ; all launcher objects
(game-launcher:find-launcher "Terraria")        ; exact lookup
(game-launcher:select-launcher "terraria")      ; fuzzy lookup
(game-launcher:select-launcher-name "terraria") ; fuzzy name only
(game-launcher:search-launcher-list "terr")     ; ranked matches
```

`select-launcher` returns the best fuzzy match or `NIL`. It does not prompt.

## Add, remove, and import

```common-lisp
;; Register an object that already exists
(game-launcher:register-launcher-instance launcher)

;; Remove by name and rewrite its store
(game-launcher:remove-launcher "Old Game")

;; Import a form or a string containing one
(game-launcher:import-launcher-form
 '(wine :name "Example" :exec "/home/me/example.exe"))
```

New launchers without provenance are written to the primary store on the next
save. Launchers loaded from a store keep that store as their destination.

## Stop a running launcher

```common-lisp
(let ((launcher (game-launcher:select-launcher "terraria")))
  (game-launcher:stop-launcher launcher :timeout 10 :force t))
```

`stop-launcher` returns the launcher and a plist with `:PID` and `:NAME` when
it stopped something. It sends `SIGTERM`, waits, then `SIGKILL` when `:FORCE`
is true. It only works for runtimes that call `note-process`.

## Paths and stores

```common-lisp
(game-launcher:store-path)                         ; primary store
(game-launcher:store-paths)                        ; primary + registered
(game-launcher:store-path :path "/tmp/store.lisp") ; select it
(game-launcher:store-path :path "/tmp/more.lisp" :add t)

(game-launcher:runtime-path)                       ; primary runtime dir
(game-launcher:runtime-paths)                      ; all runtime dirs
(game-launcher:runtime-path :path "/tmp/runtimes/" :add t)
```

`GAME_LAUNCHER_STORE` and `GAME_LAUNCHER_RUNTIMES` are consulted before the
defaults. `known-runtimes`, `load-runtime`, and `reload-runtime` control lazy
runtime loading.

## Unknown launchers

```common-lisp
(game-launcher:unknown-launcher-list)
```

Unknown forms are preserved and written back on save. They can be inspected
through this list, but cannot be launched until their runtime is available.

## Logs

```common-lisp
(game-launcher:resolve-launcher-log-path launcher)
```

Returns the current log path for a launcher, or `NIL` if it has never been
launched. Runtimes that disable logging return `NIL`.
