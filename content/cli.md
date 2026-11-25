## Synopsis

```sh
game-launcher NAME
game-launcher --list
game-launcher --remove [NAME]
game-launcher --import form|desktop|steam-id|steam-local|lutris ARGS
game-launcher --sessions
game-launcher --session-log NAME
game-launcher --session-log-path NAME
game-launcher --stop NAME
game-launcher --help [lutris|desktop|steam-local]
```

With no arguments, the CLI prints the launcher list and asks for a number.

## Commands

| Command | Description |
| --- | --- |
| `game-launcher NAME` | Fuzzy-match `NAME` against launcher names and launch it. |
| `--list` | Print every known launcher. |
| `--remove NAME` | Remove the best match from the registry and rewrite its store. Without `NAME`, show a numbered prompt. |
| `--import form FORM` | Read one launcher form from the command line and import it. |
| `--import desktop FILE` | Import a `.desktop` entry. |
| `--import steam-id ID` | Look up a Steam app ID and add it. |
| `--import steam-local all` | Import games found in the local Steam library. `dry` prints what would be imported. |
| `--import lutris all\|NAME` | Import every Lutris game or one by name. |
| `--sessions` | List active sessions recorded by the CLI. |
| `--session-log NAME` | Print the current log of a running game. |
| `--session-log-path NAME` | Print the log path only. |
| `--stop NAME` | Terminate a recorded session, escalating to `SIGKILL` if needed. |

## How a launch works

The CLI does not sit in the foreground waiting for the game to exit. It:

1. Fuzzy-matches the name, loading the appropriate runtime on demand.
2. Creates a session record.
3. Exports `GAME_LAUNCHER_SESSION` into the child environment.
4. Starts the launch thread and waits briefly for the exec phase to report a
   process.
5. Records the PID and log path, then exits.

The game is reparented to init and keeps running. Later CLI invocations use the
session record as the source of truth for `--sessions`, `--stop`, and the log
commands.

Session records live under the XDG data directory, and each launch gets a fresh
log file:

```text
~/.local/share/game-launcher/<runtime>-<time>-<random>.log
```

A `current-<runtime>-<name>.log` symlink points at the newest log, which is how
a later process finds a running game’s output.

## Name matching

`NAME` is matched with `fuzzy-match`, not a prefix search. A short unique
fragment usually works:

```sh
game-launcher touhou
```

For scripts, prefer exact launcher names to avoid surprises.

## URL handling

If the first argument starts with `game-launcher:`, the CLI splits the rest on
`/` and treats it as arguments. This is what desktop-file integrations and the
Emacs extension use to route launches through game-launcher.

```sh
game-launcher:My%20Game  # arrives as a single argument from a desktop file
```

as an example,

<style>
  .glbtn,
  .glbtn:link {
    display: inline-block;
    padding: 8px 16px;
    font: inherit;
	color: #fff;
    font-weight: 600;
    background: #141b29;
    border: 1px solid #1d4ed8;
    border-radius: 6px;
    text-decoration: none;
    cursor: pointer;
  }
</style>

<a class="glbtn" href="game-launcher:play%202048">Run 2048</a>

## Examples

```sh
# List and launch
game-launcher --list
game-launcher "Touhou 9"

# Add a one-off launcher
game-launcher --import form \
  '(EXEC :NAME "My Game" :EXEC "/home/me/games/my-game")'

# Import a desktop entry and a Steam library
game-launcher --import desktop ~/.local/share/applications/my-game.desktop
game-launcher --import steam-local all

# Inspect and stop a running game
game-launcher --sessions
game-launcher --session-log-path terraria
game-launcher --session-log terraria
game-launcher --stop terraria
```

## Import dependencies

Importers are optional systems and are only loaded when their packages are
available. The Lutris importer needs `cl-dbi`, `cl-yaml`, and `sqlite`. The
Steam importer needs `dexador` and `cl-json` for remote name lookup; local ACF
parsing has no extra dependency. See [Importing games](importing.html).
