## Inline profiles

The simplest profile is a list of string pairs:

```common-lisp
(WINE :NAME "Ragnarok Online"
      :EXEC "/home/me/.wine/drive_c/UaRo.exe"
      :PROFILE (("DXVK_ASYNC" "1")
                ("WINE_LARGE_ADDRESS_AWARE" "0")))
```

The pairs are merged over the process environment when the game launches. A
profile must be a list of two-element lists whose elements are strings;
`make-profile` rejects anything else.

## Named profiles

Duplicate environments get tedious. Name a profile in
`~/.config/game-launcher/profiles.lisp`:

```common-lisp
((PROFILE :NAME MHFZ
          :ENV (("MHF_PASS" "secret")
                ("WINEDEBUG" "-all")))
 (PROFILE :NAME TOUHOUENV
          :ENV (("DXVK_ASYNC" "1"))))
```

Then reference it by symbol from any store:

```common-lisp
(EXEC :NAME "Monster Hunter Frontier Z"
      :PROFILE MHFZ
      :EXEC "/home/me/MHFCT4.1/mhf-cli")
```

All launchers referencing `MHFZ` share one profile object. Editing the profile
once updates every launcher. Profiles are read at session start and written
back at session end.

## Creating a named profile from an inline one

Writing an inline profile plus a marker defines a named profile and replaces
the launcher’s entry with a reference the next time the store is written:

```common-lisp
(WINE :NAME "Monster Hunter Rise"
      :PROFILE (("DXVK_ASYNC" "1")) =>MHR
      :EXEC "/home/me/games/mhr.exe")
```

After the next save the form contains `:PROFILE MHR`, and the environment lives
in `profiles.lisp`. Marking an existing named profile again with a new inline
environment updates the shared profile; marking it without an environment
leaves the existing profile alone.

The marker can appear anywhere in the launcher’s top-level argument list. Its
symbol name begins with `=>`, and the profile name is the rest of that name
interned in the `GAME-LAUNCHER` package.

## How environments are built

`build-environment` starts from the current POSIX environment and applies each
profile in order. Later profiles win on collisions, so a launcher profile can
override a variable that is already set in your shell:

```common-lisp
(game-launcher:build-environment
  (game-launcher:resolve-profile 'MHFZ))
```

The UMU runtime builds a generated UMU environment first, then applies the
launcher profile on top, so explicit launcher settings win over generated
defaults.

## Programmatic profiles

You can construct profiles directly:

```common-lisp
(defparameter *my-profile*
  (game-launcher:make-profile '(("GAME_ENV" "test"))))

(game-launcher:make-launcher 'exec
                             :name "Test Game"
                             :exec "/home/me/test-game"
                             :profile *my-profile*)
```

`resolve-profile` accepts a profile object, `NIL`, an inline pair list, a
profile name symbol, or a string naming a profile. Unknown names produce a
warning and an empty profile rather than an error, which keeps a store with a
missing profile loadable.
