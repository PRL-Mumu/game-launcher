## What a runtime is

A runtime is the bridge between a launcher form and an operating-system
process. It normally provides:

1. A launcher subclass for runtime-specific fields.
2. An exec phase that starts the process.
3. A pipeline describing where that phase sits.
4. A `DEFINE-LAUNCHER-RUNTIME` form that maps a symbol and class to a
   constructor.

Runtimes are discovered lazily. The core scans runtime directories, reads
`DEFINE-LAUNCHER-RUNTIME` declarations without evaluating the files, and loads
the matching `runtime.lisp` only when a launcher needs it.

## Built-in runtimes

| Symbol | Class | What it starts |
| --- | --- | --- |
| `EXEC` | `executable-launcher` | A native executable with optional `:ARGS`. Process and log are tracked. |
| `WINE` | `wine-launcher` | `wine EXEC ARGS`, with the working directory set to the executable’s directory. Tracks the process. |
| `STEAM` | `steam-launcher` | `steam EXEC`, where `EXEC` is typically `steam://rungameid/…`. Steam owns the process, so it is not tracked. |
| `BROWSER` | `browser-launcher` | `xdg-open URL`. Uses `:URL` and does not track a process. |
| `UMU` | `umu-launcher` | `umu-run EXEC ARGS` with a generated UMU environment merged with the launcher profile. |
| `EASYRPG-PLAYER` | `easyrpg-player-launcher` | `easyrpg-player EXEC` in the game directory. |
| `VITA3K` | `vita3k-launcher` | `vita3k -r EXEC`, where `EXEC` is a Vita title ID. |
| `XSYSTEM4` | `xsystem4-launcher` | `xsystem4` with the executable’s directory. |
| `RPGMAKER` | `rpgmaker-linux-launcher` | `rpgmaker-linux EXEC`; becomes an `EXEC` launcher on Windows. |

Runtimes that launch through another daemon (`STEAM`, `BROWSER`, `VITA3K`)
intentionally leave `:PROCESS` unset, so `--stop` has nothing to manage.

## Runtime directories

By default the core searches:

```text
<game-launcher source>/src/runtimes/
```

Add more directories with the environment variable:

```sh
export GAME_LAUNCHER_RUNTIMES="$HOME/.local/share/game-launcher/runtimes"
```

or from Lisp:

```common-lisp
(game-launcher:runtime-path :path "/home/me/runtimes/" :add t)
```

Each immediate subdirectory is expected to contain a `runtime.lisp`. That file
can define classes, phases, and one or more runtimes.

## Discovery and loading

```common-lisp
;; All runtime symbols without loading their files
(game-launcher:known-runtimes)

;; Force a load of one runtime
(game-launcher:load-runtime nil 'wine)

;; Reload after editing a runtime file
(game-launcher:reload-runtime nil 'wine)
```

`load-runtime` rescans the registered directories on a miss, so a runtime
added after startup is still found. Symbol-name comparison is case-insensitive,
which lets a runtime symbol from another package resolve to the same file.

`make-launcher` calls `load-runtime` before looking up the constructor. If no
runtime matches, it signals `unknown-runtime`; store loading catches that and
preserves the form as an unknown launcher.

## Minimal runtime sketch

```common-lisp
(in-package #:game-launcher)

(defclass my-launcher (launcher)
  ((args :initarg :args :accessor launcher-args)))

(defun my-exec (ctx)
  (let ((process (sb-ext:run-program
                  "my-runner"
                  (cons (getf ctx :exec) (split-shell-args (getf ctx :args)))
                  :environment (getf ctx :env)
                  :output (getf ctx :log-path)
                  :error (getf ctx :log-path)
                  :search t
                  :wait nil)))
    (note-process ctx process)
    (sb-ext:process-wait process)
    ctx))

(defparameter *my-pipeline*
  '((pre  . nil)
    (exec . my-exec)
    (post . nil)
    (teardown . teardown-processes)))

(define-standard-pipeline-launch my-launcher *my-pipeline*)

(define-launcher-runtime my-runtime my-launcher)
```

The next page explains pipelines and phase clauses in detail.
