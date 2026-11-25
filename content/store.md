## Where stores live

The primary store is resolved in this order:

1. `GAME_LAUNCHER_STORE`
2. `~/.config/game-launcher/launcher-store.lisp` or
   `C:/users/YourUsername/AppData/Local/config/game-launcher/launcher-store.lisp`
3. the bundled `src/store/launcher-store.lisp` 

A store is a single top-level list of forms. It is read as Lisp with
`*read-eval*` disabled, so `#.` is never evaluated. Unknown fields and unknown
runtime symbols survive a load/save cycle whenever possible.

## Launcher forms

Every launcher starts with its runtime symbol and a name:

```common-lisp
(EXEC  :NAME "Cataclysm Bright Nights" :EXEC "/home/me/games/cataclysm-launcher")
(WINE  :NAME "Touhou 9" :EXEC "/home/me/games/th09.exe" :PROFILE TOUHOUENV)
(STEAM :NAME "Terraria" :EXEC "steam://rungameid/105600")
```

Common fields:

| Field | Meaning |
| --- | --- |
| runtime symbol | Selects the launcher class and launch method. Must be a registered runtime. |
| `:NAME` | Unique display name, also used for matching and session records. |
| `:EXEC` | Executable, command, or URL passed to the runtime. |
| `:URL` | Browser-specific URL field; `BROWSER` also accepts `:EXEC`. |
| `:ARGS` | Argument string or list. Strings are split with shell-like quoting. |
| `:PROFILE` | Inline environment pairs or a named profile symbol. |
| `:PHASES` | Pipeline modification clauses. See [Launch phases](phases.html). |
| `:TAGS` | Free-form tags preserved in the form. |
| `:LUTRIS-ID` | Lutris database ID used by the Wine, browser, and UMU runtimes. |

Runtime-specific fields are added by `launcher->form` methods. For example,
`EXEC` and `WINE` write `:ARGS`, while `BROWSER` writes `:URL` instead of
`:EXEC`.

## Store trees

Large libraries are easier to split. A store tree file, normally
`~/.config/game-launcher/games/store-tree.lisp`, lists other stores:

```common-lisp
("Monster Hunter/MHFZ.lisp")        ; one file
("extra/")                           ; every file directly in this directory
(:store-file "lutris/lutris.lisp")   ; explicit file reference
(:store-tree "emulators/tree.lisp")  ; nested tree

;; Anything else is code and is evaluated when the tree loads.
(defvar *my-launcher-setting* t)
```

Paths are relative to the tree file. Directories are scanned
non-recursively. `.bak` files are skipped so backups are never re-read as
stores.

Inside a store file, `:store-file` and `:store-tree` forms load additional
stores; they are not launcher definitions. A store tree is deliberately more
powerful than a store: non-reference forms in a tree are evaluated in the
`GAME-LAUNCHER` package. Treat tree files as code you trust.

## Writing stores back

Each launcher and unknown form records the store file it came from. On exit,
`write-all-stores` writes each file with only the definitions that originated
there. Definitions added at runtime without provenance go to the primary
store, together with the primary store’s own definitions.

The writer:

- uses a temporary file and `rename-file` for atomic replacement;
- copies the previous store to a `.bak` before replacing it;
- refuses to overwrite a store it cannot read;
- skips the write entirely when the file already contains the same forms
  (form order is ignored), so a session that changed nothing leaves the file
  and its timestamp alone.

This means editing a store by hand is safe as long as the file remains one
readable list of forms. A malformed store is reported and preserved rather
than silently truncated.

## Unknown runtimes

If a store references a runtime that is not installed, the form is kept as an
unknown launcher and written back unchanged on the next save. This lets a
store move between machines with different runtime sets without losing games.

Unknown launchers cannot be launched until the runtime becomes available
again.

## Primary store and imports

Store entries added by `--import` use the primary store path. To keep imports
separate, point `GAME_LAUNCHER_STORE` at a dedicated file or add a store tree
that references per-system files. Provenance keeps the split stable: each
definition is written back to the store it came from, not to whichever file
happens to be loaded last.

## Related files

| Path | Purpose |
| --- | --- |
| `~/.config/game-launcher/launcher-store.lisp` | Default primary store |
| `~/.config/game-launcher/profiles.lisp` | Named environment profiles |
| `~/.config/game-launcher/games/store-tree.lisp` | Conventional store tree |
| `*<store>*.bak` | Previous version of a store, written before replacement |
| `~/.local/share/game-launcher/*.log` | Launch logs |
