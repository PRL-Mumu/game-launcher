## Source layout

| Area | Responsibility |
| --- | --- |
| `src/registry.lisp` | Launcher/runtime registries, store reading and writing, provenance, path resolution, initialization. |
| `src/launcher.lisp` | Frontend helpers: listing, fuzzy selection, prompting, threaded launches. |
| `src/utils/profile.lisp` | Profiles, named profile file, environment construction. |
| `src/runtimes/launcher-class.lisp` | Base launcher class, runtime registration, runtime discovery and loading. |
| `src/runtimes/launch-pipeline.lisp` | Pipeline data structure, clause application, command helpers, logging, teardown. |
| `src/runtimes/unknown-launcher-class.lisp` | Container for forms whose runtime is unavailable. |
| `src/imports/import.lisp` | The generic `import-launcher-form` entry point. |
| `src/runtimes/<name>/runtime.lisp` | One runtime each: class, exec phase, pipeline, registration. |
| `src/runtimes/*-importer/` | Optional importer systems. |
| `subprojects/session/` | Session records used by the CLI for `--sessions` and `--stop`. |

## Load flow

`initialize-launcher` performs a fixed sequence:

1. Clear the in-memory registry (`uninitialize-launcher`).
2. Read named profiles from `~/.config/game-launcher/profiles.lisp`.
3. Read the default store tree, if present.
4. Load every known store and follow `:store-file` / `:store-tree` references
   to a fixpoint, keeping a processed set so cycles terminate.
5. Mark the image as initialized, which enables safe writes.

Each launcher form read from a file is passed to `make-launcher`. The runtime
is loaded on demand. If the runtime is missing or the form is malformed, it is
stored as an unknown launcher instead of being discarded. Both launchers and
unknown forms record the store file they came from.

## Runtime discovery

Runtime symbols are indexed without evaluating runtime files. The indexer
scans each immediate subdirectory of the runtime roots, reads
`runtime.lisp`, tracks `IN-PACKAGE`, and collects `DEFINE-LAUNCHER-RUNTIME`
declarations. `load-runtime` loads the matching file once and caches the fact.
A miss triggers a rescan, so adding a runtime while the image is running still
works.

`DEFINE-LAUNCHER-RUNTIME` finalizes the class, defines `launcher-runtime`,
generates a keyword constructor from the class slots when needed, and registers
the constructor under the runtime symbol.

## Launch flow

`launch` applies the launcher’s `:PHASES` clauses to the runtime’s default
pipeline, builds a context, and runs each non-`NIL` phase. Exec phases start the
OS process, call `note-process` for runtimes that can be stopped, and wait for
exit. `run-pipeline` catches errors and interrupts and always runs teardown for
the processes collected so far.

Session records are a CLI-level concern. The CLI starts the launch in a thread,
waits briefly for the PID, writes a session record, and exits without joining
the thread. The game survives because it is reparented to init. The record is
what later invocations use to find logs or send signals.

## Write flow

`end-launcher` calls `write-all-stores`:

1. Every non-primary store is written with only the launchers/unknown forms
   whose provenance points at it.
2. The primary store is written with its own forms plus orphan forms that have
   no provenance.
3. Structural `:store-file` / `:store-tree` forms are preserved: recorded
   markers are used when present, otherwise the file’s existing markers are
   kept.

`write-launchers-to-file` reads the existing file first. If it cannot be read,
the write is refused. It compares the existing forms to the new forms as a
multiset, ignoring order. If they match, nothing is written and no backup is
made. Otherwise it copies the old file to `.bak`, pretty-prints the new forms
to a temp file, and renames the temp file over the original.

This design keeps hand-edited formatting from being churned unnecessarily while
still guaranteeing that a data change is persisted atomically.

## Design boundaries

- The core does not know about storefronts; importers are separate systems.
- Runtimes own process creation; the core owns the pipeline and persistence.
- Unknown data survives round trips.
- Frontends (CLI, GUI, Emacs) sit on the same exported registry API.
- SBCL-specific process and thread APIs are used directly rather than hidden
  behind another portability layer.
