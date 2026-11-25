## Pipeline shape

A launch pipeline is an ordered alist of `(name . function)` pairs. A `NIL`
function is an anchor: it exists only to give `ADD-BEFORE` and `ADD-AFTER`
something to attach to.

```common-lisp
(defparameter *my-pipeline*
  '((pre  . nil)
    (exec . my-exec-phase)
    (post . nil)
    (teardown . teardown-processes)))
```

`run-pipeline` calls each non-`NIL` function with the launch context and
threads the returned context into the next phase. Anchors are skipped.

## Modifying a pipeline from a store

The `:PHASES` field of a launcher contains clauses. They are applied to the
runtime’s default pipeline in order:

| Clause | Effect |
| --- | --- |
| `(ADD-BEFORE ANCHOR NAME FN)` | Insert `NAME` immediately before `ANCHOR`. |
| `(ADD-AFTER ANCHOR NAME FN)` | Insert `NAME` immediately after `ANCHOR`. |
| `(REPLACE NAME FN)` | Replace an existing phase’s function. |
| `(DELETE NAME)` | Remove a phase. |

Phase functions may be a function object, a symbol naming a function, or a
form. A form is compiled into a one-argument function; inside it, `CTX` names
the launch context.

```common-lisp
(EXEC :NAME "Monster Hunter Frontier Z"
      :EXEC "/home/me/Downloads/MHFCT4.1/mhf-cli"
      :PHASES
      ((REPLACE PRE
                (RUN-COMMAND CTX
                             (SPLIT-SHELL-ARGS
                              "pg_ctl -D /home/me/pg -l /home/me/pg/server.log start")))
       (ADD-AFTER EXEC SERVER
                  (RUN-COMMAND-ASYNC CTX '("/home/me/erupe-ce")))
       (ADD-AFTER SERVER DELAY (SLEEP 10))
       (REPLACE POST
                (RUN-COMMAND CTX
                             (SPLIT-SHELL-ARGS
                              "pg_ctl -D /home/me/pg -l /home/me/pg/server.log stop"))))
      :ARGS "-u MMOFAN --char-id 5")
```

Exec phases generally wait for the game process, so `POST` runs after the game
exits. Phases added after `EXEC` run once the exec phase returns.

## Launch context

`standard-ctx` builds a plist containing:

| Key | Value |
| --- | --- |
| `:launcher` | The launcher object. |
| `:exec` | `launcher-exec`. |
| `:env` | Environment string list built from the launcher profile. |
| `:log-path` | An open log stream, or `NIL` when the runtime disables logging. |
| `:process` | The main tracked OS process, when the runtime sets it. |
| `:processes` | Extra processes/threads torn down at the end. |
| `:args` | Runtime-specific arguments, added by `EXEC`, `WINE`, and `UMU`. |

Phase functions return the context. A phase that mutates `:PROCESSES` should
return `CTX` so later phases see the update.

## Helper functions

```common-lisp
;; Split a shell-like argument string, respecting quotes.
(split-shell-args "-u MMOFAN --char-id 5")

;; Run and wait. An error exit code becomes a Lisp error.
(run-command ctx '("pg_ctl" "start"))

;; Start in the background and remember the process in :PROCESSES.
(run-command-async ctx '("/home/me/server") :wait nil)

;; Track the main process so --stop and teardown can find it.
(note-process ctx process)
```

`teardown-processes` closes the log stream and terminates every entry in
`:PROCESSES`. Entries can be OS processes or `(thread . stop-function)` conses.
It sends `SIGTERM`, waits, then escalates to `SIGKILL`.

`run-pipeline` calls teardown when a phase signals an error or the user
interrupts the launch, so a failed game start does not leave helper daemons
running.

## Trust model

Phase forms are Lisp code and are compiled and executed. Store files disable
`#.` while reading, but a `:PHASES` form is still code. Only load stores you
trust, and prefer symbolic phase functions for shared stores.
