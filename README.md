# Guild Wars 2 Linux Multibox Launcher Script

Gw2Launcher is a fantastic tool for windows, and the author is thankfully
responsive to Linux issues, but the tool relies on a poorly documented Windows
feature to kill the GW2 mutex which does not always consistently work through
`wine`. See https://github.com/Healix/Gw2Launcher/issues/249#issuecomment-1383022346
for the comment which inspired me to build this.

Because each `WINEPREFIX` has a separate windows-like environment, the mutex is
not shared between `WINEPREFIX`s, allowing simultaneous instances of the game
from distinct `WINEPREFIX`s. However, the `Gw2.dat` file is 66 G and counting,
making storing multiple instances challenging.

This script uses `fuse-overlayfs` and `xdotool` to dynamically create
`WINEPREFIX`s with minimal overhead, run the game, and detect launches (allowing
sequential launch to avoid X11 CPU overuse trying to draw overlapping odd
geometry partially transparent windows). Other dependencies which are _usually_
installed by default: `bash`, `setsid` (probably from `util-linux`) and `pgrep`
(probably from `procps-ng`).

It requires you to already be able to run GW2 from the command line (if you
have a working install via Lutris, you can generate one with something like
`lutris guild-wars-2 --output-script gw2.sh`). You need a working cli launch
script, as you use configuration from that to tell this runner how to launch the
game.

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

    gw2-alt.sh -c 01 02 03 # create mounts and run
    gw2-alt.sh -x 01 02 03 # close each
    gw2-alt.sh -d 01 02 03 # remove mounts

When the game releases updates, first run:

    gw2-alt.sh -cu 01 02 03 # create mounts and update
    gw2-alt.sh 01 02 03 # run, given mounts exist already

To change saved username/password or settings in one account at a time:

    gw2-alt.sh -o 01 # change options/configure

## Initial setup

1. Install GW2 normally and ensure it runs.
2. Create a launch script, and ensure it runs GW2 from the command line
3. Backup your `GFXSettings.GW2-64.exe.xml` (in `<gw2 WINEPREFIX>/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/`), run the game and set graphics to values you'd like to run multiple clients with (all minimums likely), then stash the modified `GFXSettings.GW2-64.exe.xml` and restore your nice one for regular use.
4. Run the script - make sure it's executable (`chmod +x <downloaded filename>`)
5. Choose a base location for the script to use to run and store data, create
   `$XDG_CONFIG_HOME/gw2alts`, and update `$XDG_CONFIG_HOME/gw2alts/config.sh`
   as directed.
6. Run again
7. Copy your `GFXSettings.GW2-64.exe.xml` to the `conf` folder of the directory
   you chose for the script to use.

Once you're set up, you can create new `Local.dat`s for each account with
`gw2-alt.sh -co "<name>"`, then enter username, password, save them (unless you
like retyping them each time you launch), launch the game and change settings
however you'd like (you can't change them during normal launches, only when
launching with `-o`, which launches the game in exclusive mode), then exit. This
should set things up so that in the future you can set up and launch multiple
accounts with just `gw2-alt.sh "<name>" "<name 2>"`, etc as normal. Quotes
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

### Core Idea

If you run into trouble, you can see if the basic idea works on your system
manually, to see if the core concept is causing trouble or the helpful
automation is wrong. The core steps the script does are:

To set up an account:
1. Create `upper-account-name` and `work-account-name` directories and run `fuse-overlayfs -o lowerdir="$GW2_BASE_WINEPREFIX" -o upperdir="upper-account-name" -o workdir="work-account-name" account-name`. This creates a COW clone of the GW2_BASE_WINEPREFIX which should remain tiny
2. Back up your Local.dat from `$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat`, launch the game and set up the alt account the way you want it, copy the new Local.dat file somewhere like `account-name.dat` and restore your backed up `Local.dat` file.
3. Do the same for `GFXSettings.Gw2-64.exe.xml`, found in `$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/` - back up the original, set up graphics settings for the alts, save the new file elsewhere and restore the original
4. Copy the `GFXSettings.Gw2-64.exe.xml` to `account-name/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/` and `account-name.dat` file to `account-name/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat`. This overwrites only those files in the COW version of the game directory.
5. Launch the game with your normal command-line launcher script, except change the `WINEPREFIX` to be `account-name` instead of `$GW2_BASE_WINEPREFIX`, and you must pass the `-shareArchive` flag to GW2 or the game does a deep copy of the install since the game files are opened in exclusive mode. An example command: WINEPREFIX=account-name wine "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/Gw2-64.exe" -shareArchive -windowed

## License

This script is licensed under the terms of the WTFPL version 2.

If you submit any pull requests, you agree to license them under the same, to
avoid potential legal headaches I'd rather not deal with.
