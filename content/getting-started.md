## Requirements

- **SBCL.** The runtime and pipeline code uses SBCL-specific APIs
  (`sb-ext:run-program`, `sb-thread`, `sb-posix`), so SBCL is the supported
  implementation.
- **ASDF and Quicklisp** for building from source and loading dependencies.
- **Roswell** if you want the packaged CLI build described below.

## Install the CLI

The shortest route is using Roswell:

```sh
ros install PRL-Mumu/game-launcher
```

note: for windows refresh the quicklisp local projects

``` sh
# in cmd
$ sbcl # or ros.exe run
* (ql:register-local-projects)
```

Or clone the repository into a path in asdf source registry (~/common-lisp)
and install the built binaries:

```sh
git clone https://github.com/PRL-Mumu/game-launcher.git
cd game-launcher
make install
```

note: for windows the source registry is at **"C:\Users\\(YourUsername)\quicklisp\local-projects\"**

`make install` builds `game-launcher` and `gamelauncher-gui`, installs them
under `~/.roswell/bin`, and installs a desktop entry (for unix) if one is not already
present.

Build without installing:

```sh
make buildcli
make buildgui
```

## Give it a store

game-launcher looks for its primary store in this order:

1. `GAME_LAUNCHER_STORE`
2. `~/.config/game-launcher/launcher-store.lisp` or
   `C:/users/YourUsername/AppData/Local/config/game-launcher/launcher-store.lisp`
3. the bundled `src/store/launcher-store.lisp` from the source tree

For a normal install, create the config file:

```sh
mkdir -p ~/.config/game-launcher
$EDITOR ~/.config/game-launcher/launcher-store.lisp
```

A store is one top-level list of launcher forms:

```common-lisp
((EXEC :NAME "Cataclysm Bright Nights"
       :EXEC "/home/me/Games/cataclysmbn-v0.12.0/cataclysm-launcher")
 (STEAM :NAME "Terraria"
        :EXEC "steam://rungameid/105600"))
```

The runtime symbol (`EXEC`, `STEAM`, `WINE`, …) must match a runtime found in
the runtime directories. Bundled runtimes are discovered automatically. The
full format is described in [Store files](store.html).

## First launch

List everything the launcher can see:

```sh
game-launcher --list
```

Launch a game by name. Matching is fuzzy, so a unique fragment is enough:

```sh
game-launcher terraria
```

If nothing matches, game-launcher says so rather than guessing. When several
launchers match, prefer the full name.

## Import instead of typing

If the game already exists in a desktop file, Lutris, or a local Steam library,
import it:

```sh
game-launcher --import desktop /usr/share/applications/some-game.desktop
game-launcher --import lutris all
game-launcher --import steam-local all
```

See [Importing games](importing.html) for dependencies and caveats.

## Build from source as a library

game-launcher is also an ASDF system. From a Lisp REPL with Quicklisp loaded:

```common-lisp
(ql:quickload :game-launcher)

(game-launcher:with-launcher-session ()
  (game-launcher:display-launchers (game-launcher:launcher-list)))
```

`with-launcher-session` reads profiles and every store, runs the body, then
writes the stores and profiles back on exit. Use it whenever you modify
launchers or profiles and expect the changes to persist.

## Useful environment variables

| Variable | Effect |
| --- | --- |
| `GAME_LAUNCHER_STORE` | Use this file as the primary store. |
| `GAME_LAUNCHER_RUNTIMES` | Add a runtime directory to the search path. |

Both can also be set programmatically with `store-path` and `runtime-path`
using their `:path` and `:add` arguments.
