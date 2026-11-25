## Importers are extensions

Importers live beside runtimes and are loaded only when their dependencies are
present. The core does not require a database driver or an HTTP client, so a
minimal install stays small.

Imported launchers are registered exactly like hand-written ones. They inherit
the normal provenance rules, so the next store save writes them to the primary
store unless you arrange a different destination.

## Desktop entries

```sh
game-launcher --import desktop ~/.local/share/applications/my-game.desktop
```

The desktop importer reads `Name`, `Exec`, and `Path`, strips desktop field
codes such as `%U` and `%f`, and creates an `EXEC` launcher. The first token
becomes `:EXEC` and the rest becomes `:ARGS`.

Programmatically:

```common-lisp
(game-launcher.desktop:import-desktop-file
 "/usr/share/applications/some-game.desktop")
```

The importer is only loaded on Unix-like systems.

## Lutris

Enable the importer by making sure these systems are installed:

- `cl-dbi`
- `cl-yaml`
- `sqlite`

Then import one game or the whole library:

```sh
game-launcher --import lutris "Some Game"
game-launcher --import lutris all
```

The importer reads the Lutris database and each game’s YAML configuration. It
supports the `wine`, `linux`, and `web` runners:

| Lutris runner | Result |
| --- | --- |
| `wine` | `WINE` launcher with executable, arguments, environment profile, and Lutris ID. |
| `linux` | `EXEC` launcher with executable, arguments, and environment profile. |
| `web` | `BROWSER` launcher with the game’s main URL. |

Other runners are skipped with a warning. Programmatic entry points are
`game-launcher.lutris:import-lutris-game` and
`import-all-lutris-games`.

## Steam

Remote lookups use `dexador` and `cl-json`. Local ACF parsing has no extra
dependency.

```sh
# One app by ID or URL
game-launcher --import steam-id 105600
game-launcher --import steam-id https://store.steampowered.com/app/105600/

# Everything in the local Steam libraries
game-launcher --import steam-local all

# Preview without registering anything
game-launcher --import steam-local dry
```

`steam-local` reads `libraryfolders.vdf` under the XDG data directory, locates
every `appmanifest_*.acf`, and creates a `STEAM` launcher whose `:EXEC` is
`steam://rungameid/<id>`. Runtime/tooling app IDs are blacklisted and skipped.

Programmatic entry points:

```common-lisp
(game-launcher.steam:import-steam-id "105600")
(game-launcher.steam:steam-local-import-all)
(game-launcher.steam:steam-local-import-all :dry t)
(game-launcher.steam:steam-local-import "105600" "/path/to/Steam")
```

## One-off forms

For a single launcher, skip the importers:

```sh
game-launcher --import form '(EXEC :NAME "Test" :EXEC "/home/me/test")'
```

or from Lisp:

```common-lisp
(game-launcher:import-launcher-form
 '(exec :name "Test" :exec "/home/me/test"))
```

`import-launcher-form` accepts either a form or a string containing one. It
reports and skips anything that is not a launcher form.

## Where imported games go

All importers call `register-launcher-instance`. At the end of the CLI session,
the store writer puts each new launcher in the primary store (or in another
store if you set its provenance yourself). Restart the CLI, or run
`--list`, to see the result.
