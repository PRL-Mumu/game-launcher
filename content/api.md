The following symbols are exported from `GAME-LAUNCHER`. Runtime-specific
classes and constructors are exported separately by their runtime files and
are not listed here.

## Launcher objects

| Symbol | Summary |
| --- | --- |
| `launcher` | Base class holding name, exec, profile, phases, tags, process, and lock. |
| `launcherp` | Generic predicate; true for launcher instances. |
| `make-launcher RUNTIME &REST ARGS` | Load `RUNTIME`, resolve profiles/markers, and construct a launcher. |
| `launcher-name` | Accessor for the display name. |
| `launcher-runtime` | Generic returning the runtime symbol. |
| `launcher-exec` | Accessor for the executable/URL field. |
| `launcher-profile` | Accessor for the resolved profile object. |
| `launch` | Generic that runs the launcher pipeline. |
| `stop-launcher LAUNCHER &KEY TIMEOUT FORCE` | Stop the tracked process. Returns the launcher and a `:PID`/`:NAME` plist when something was stopped. |

## Sessions and registry

| Symbol | Summary |
| --- | --- |
| `with-launcher-session (()) &BODY BODY` | Initialize, run the body, and write stores/profiles on exit. |
| `initialize-launcher` | Read profiles, store tree, and all stores. |
| `end-launcher` | Write stores and profiles, then clear the registry. |
| `uninitialize-launcher` | Clear in-memory state without writing. |
| `register-launcher RUNTIME CONSTRUCTOR` | Register a constructor for a runtime symbol. |
| `register-launcher-instance LAUNCHER` | Add or replace a launcher by name. |
| `launcher-names` | List all launcher names as strings. |
| `launcher-list` | List all launcher objects. |
| `find-launcher NAME` | Exact lookup. |
| `remove-launcher NAME` | Remove a launcher and rewrite its source store. |
| `select-launcher QUERY` | Fuzzy-match and return the best launcher or `NIL`. |
| `select-launcher-name QUERY` | Fuzzy-match and return the best name or `NIL`. |
| `search-launcher-list QUERY` | Return fuzzy matches over launcher names. |
| `display-launchers LAUNCHERS` | Print a numbered list of names. |
| `list-launchers` | Print the whole registry. |
| `list-unknown-launchers` | Print preserved unknown forms. |
| `unknown-launcher-list` | Return the unknown launcher objects. |
| `prompt-launcher-list` | Print a numbered list and launch the chosen entry. |
| `prompt-launcher-remove-list` | Print a numbered list and remove the chosen entry. |
| `run-launcher-thread LAUNCHER` | Launch in a new thread, reporting errors. |

## Stores

| Symbol | Summary |
| --- | --- |
| `store-path &KEY PATH ADD` | Get or set the primary store; `ADD` registers without replacing. |
| `store-paths` | Primary store plus every registered store. |
| `write-launchers-to-file FILE &KEY SOURCE INCLUDE-ORPHANS` | Write launcher forms atomically, skipping the write when unchanged. |
| `write-all-stores` | Write every store with provenance-aware contents. |

## Runtimes

| Symbol | Summary |
| --- | --- |
| `define-launcher-runtime NAME CLASS &OPTIONAL CONSTRUCTOR` | Register a runtime symbol and generate a constructor when none is supplied. |
| `load-runtime DIR RUNTIME` | Load the runtime file for `RUNTIME` (`DIR` is ignored for compatibility). |
| `reload-runtime DIR RUNTIME` | Force a runtime file to load again. |
| `known-runtimes &OPTIONAL DIR` | List runtime symbols found on disk without loading them. |
| `runtime-path &KEY PATH ADD` | Get or set the primary runtime directory. |
| `runtime-paths` | Primary runtime directory plus every registered directory. |
| `rush-debug-load-runtimes` | Reload every known runtime in the current image. |

## Import and logs

| Symbol | Summary |
| --- | --- |
| `import-launcher-form FORM-OR-STRING` | Read and register one launcher form. |
| `resolve-launcher-log-path LAUNCHER` | Return the current session log path, or `NIL`. |
