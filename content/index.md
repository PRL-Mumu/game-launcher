**game-launcher** is a Common Lisp framework for describing games, their launch
configuration, and the runtime needed to start them. It is a library first and
a comes with a command-line launcher: the same launcher objects can be driven from a
CLI, an editor extension, a GUI, or your own Lisp code.

It is not tied to a storefront. A game can be a native executable, a Wine
prefix, a Steam URL, a browser page, or a custom pipeline that starts a
database before the game and stops it afterwards.

## Why game-launcher?

Most launchers assume one ecosystem. game-launcher starts from the opposite
direction: a launch configuration is plain Lisp data, and a runtime is a small
piece of code that knows how to execute it.

- **Data first.** Games live in editable store files, not an opaque database.
- **Runtime agnostic.** Wine, Steam, native executables, browser pages, and
  emulators share one launcher model.
- **Extensible.** Add a runtime in a directory. Add phases in a store form.
  Add an importer as a separate system.
- **Preserve what you do not understand.** Unknown runtimes are round-tripped
  rather than dropped.
- **Small core.** The core dependency layer stays small enough to embed.

## A short tour

A launcher is a Lisp form with a runtime symbol and a name:

```common-lisp
(EXEC :NAME "Cataclysm Bright Nights"
      :EXEC "/home/me/Games/cataclysmbn-v0.12.0/cataclysm-launcher")
```

Launch it from the command line by (fuzzy) name:

```sh
game-launcher cataclysm
```

Or use the library directly:

```common-lisp
(game-launcher:with-launcher-session ()
  (let ((launcher (game-launcher:select-launcher "cataclysm")))
    (game-launcher:launch launcher)))
```

A more involved game can define phases. This example starts PostgreSQL before
the game, starts a private server alongside it, waits ten seconds, then stops
PostgreSQL afterwards:

```common-lisp
(EXEC :NAME "Monster Hunter Frontier Z"
      :EXEC "/home/me/Downloads/MHFCT4.1/mhf-cli"
      :PHASES
      ((REPLACE PRE
                (RUN-COMMAND CTX
                             (SPLIT-SHELL-ARGS
                              "pg_ctl -D /home/me/pg -l /home/me/pg/server.log start")))
       (ADD-AFTER EXEC SERVER
                  (RUN-COMMAND-ASYNC CTX '("/home/me/erupe")))
       (ADD-AFTER SERVER DELAY (SLEEP 10))
       (REPLACE POST
                (RUN-COMMAND CTX
                             (SPLIT-SHELL-ARGS
                              "pg_ctl -D /home/me/pg -l /home/me/pg/server.log stop"))))
      :PROFILE MHFZ
      :ARGS "-u MMOFAN --char-id 5")
```

## The moving parts

| Part | What it does | Read more |
| --- | --- | --- |
| Launcher | An object holding a name, executable, arguments, profile, and phases. | [Using it as a library](library.html) |
| Runtime | A class plus launch method registered under a symbol such as `WINE`. | [Runtimes](runtimes.html) |
| Store | A Lisp file (or tree of files) containing launcher forms. | [Store files](store.html) |
| Profile | Shared environment variables referenced by name. | [Profiles](profiles.html) |
| Pipeline | Ordered phases around the launch step. | [Launch phases](phases.html) |
| Importer | Optional code that turns desktop, Lutris, or Steam data into launchers. | [Importing games](importing.html) |

## Current status

The project is at version **0.5.0**. It targets SBCL on Windows and Unix-like systems and
is licensed under the GPLv3. Runtime discovery, store trees, named profiles,
launch phases, session tracking, and desktop/Lutris/Steam importers are all
implemented.

Start with [Getting started](getting-started.html), or jump straight to the
[store format](store.html) if you already have SBCL and Roswell installed.
