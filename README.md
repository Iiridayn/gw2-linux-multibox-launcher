# Guild Wars 2 Linux Multibox Launcher Script

Gw2Launcher is a fantastic tool for windows, and the author is thankfully
responsive to Linux issues, but the tool relies on a poorly documented Windows
feature to kill the GW2 mutex which does not always consistently work through
`wine`.

Because each `WINEPREFIX` has a separate windows-like environment, the mutex is
not shared between `WINEPREFIX`s, allowing simultaneous instances of the game
from distinct `WINEPREFIX`s. However, the `Gw2.dat` file is 66 G and counting,
making storing multiple instances challenging.

This script uses `fuse-overlayfs`, `setsid`, and `xdotool` to dynamically create
`WINEPREFIX`s with minimal overhead, run the game, and detect launches (allowing
sequential launch to avoid X11 CPU overuse trying to draw overlapping odd
geometry partially transparent windows).

It requires you to already be able to run GW2 from the command line (if you
have a working install via Lutris, you can use something like `lutris
guild-wars-2 --output-script gw2.sh`).

It works great on the two machines I use (both Arch Linux, one installed
w/Lutris and one w/o), but will need broader testing to verify it works for
others; consider this an alpha release. The command line options _may_ change.

## Support

Please let me know if you find any bugs - especially if you also have
generalizable fixes. I may not have time to add features, and want to keep the
script relatively simple - if you have a great idea, feel free to let me know
about it, implement it, and/or fork the codebase as necessary.

If you'd like help running this, or are having trouble installing GW2 on your
Linux distribution I'd be interested in helping. Contact me via email or Discord
(iiridayn, iiridayn+gw2alts@gmail.com) if you've exhausted other support avenues
and are willing to wait around for me to be available to help. Follow the
principle of [don't ask to ask](https://dontasktoask.com).

## Usage examples

If you don't want a bunch of fuser mounts in your system between runs:

    gw2-alt.sh -s 01 02 03 # setup and run
    gw2-alt.sh -cd 01 02 03 # close and remove

When the game releases updates, first run:

    gw2-alt.sh -su 01 02 03 # setup and update
    gw2-alt.sh 01 02 03 # run after an update

## Initial setup

1. Install GW2 normally and ensure it runs.
2. Create a launch script, and ensure it runs GW2 from the command line
3. Backup your `GFXSettings.GW2-64.exe.xml` (in `<gw2 WINEPREFIX>/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/`), run the game and set graphics to values you'd like to run multiple clients with (all minimums likely), then stash the modified `GFXSettings.GW2-64.exe.xml` and restore your nice one for regular use.
4. Run the script
5. Choose a base location for the script to use to run and store data, create
   `$XDG_CONFIG_HOME/gw2alts`, and update `$XDG_CONFIG_HOME/gw2alts/config.sh`
   as directed.
6. Run again
7. Copy your `GFXSettings.GW2-64.exe.xml` to the `conf` folder of the directory
   you chose for the script to use.

Once you're set up, you can create new `Local.dat`s for each account with
`gw2-alt.sh -o "<name>"`, then enter username, password, save them (unless you
like retyping them each time you launch), launch the game and change settings
however you'd like (you can't change them during normal launches, only when
launching with `-o`, which launches the game in exclusive mode), then exit. This
should set things up so that in the future you can set up and launch multiple
accounts with just `gw2-alt.sh -s "<name>" "<name 2>"`, etc as normal. Quotes
are only needed if you want a space in the account name, which I've not tested
yet but should probably work.

## Troubleshooting

- Arbitrary clients crash occasionally: relaunch that account. The game does
  that, which is why the name is in the window title, to make it easier to spot
  which account crashed.
- The login screen won't load, some red text about downloading (I think?):
  update each account by running `gw2-alt.sh -u "<name>" "<name 2>"` etc, then
  try launching normally. If one crashes during the update, re-run the update
  for that one.
- My computer is too slow: reduce graphics settings (and update the stashed
  `GFXSettings.GW2-64.exe.xml`), buy more RAM (I think each account requires
  around 4 G of free RAM), get a CPU with more cores, etc. RAM is often a key
  bottleneck here.
- Something else: check the log file for the account; they often have useful
  information to diagnose and fix issues.

## License

This script is licensed under the terms of the WTFPL version 2.

If you submit any pull requests, you agree to license them under the same, to
avoid potential legal headaches I'd rather not deal with.
