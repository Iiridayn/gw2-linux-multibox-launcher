# Guild Wars 2 Linux Multibox Launcher Script

Gw2Launcher is a fantastic tool for windows, and the author is thankfully
responsive to Linux issues, but the tool relies on a poorly documented Windows
feature to kill the GW2 mutex which does not always consistently work through
`wine`. See https://github.com/Healix/Gw2Launcher/issues/249#issuecomment-1383022346
for the comment which inspired me to build this.

Because each `WINEPREFIX` has a separate windows-like environment, the mutex is
not shared between `WINEPREFIX`s, allowing simultaneous instances of the game
from distinct `WINEPREFIX`s. However, the `Gw2.dat` file is 76 G and counting,
making storing multiple instances challenging.

This script uses `fuse-overlayfs` to dynamically create `WINEPREFIX`s with
minimal overhead, runs the game, and uses `xdotool` to detect launches (allowing
sequential launch to avoid X11 CPU overuse trying to draw overlapping odd
geometry partially transparent windows). Other dependencies which are _usually_
installed by default: `bash`, `setsid` (probably from `util-linux`) and `pgrep`
(probably from `procps-ng`).

To use this script you need to already be able to run GW2 from the command line
(if you have a working install via Lutris, you can generate one with something
like `lutris guild-wars-2 --output-script gw2.sh`). You need a working cli
launch script, as you use configuration from that to tell this runner how to
launch the game.

This script works great on the two machines I use (one Arch Linux, one Fedora;
it previously worked on another Arch host without a Lutris install as well), but
will need broader testing to verify it works for others; consider this an alpha
release. The command line options have already changed once, and _may_ again.

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

Note that these examples assume you have `gw2-alt.sh` in your `PATH`.

Set up a new account (once the program is set up) or update settings:

    gw2-alt.sh -o 04 # change options/configure; only 1 account at at time

When the game releases updates, each alt must update their Local.dat:

    gw2-alt.sh -u 01 02 03 # run in update-only mode

Launch multiple accounts, waiting for each to load before launching the next:

    gw2-alt.sh 01 02 03

## Installation

1. Install GW2 normally and ensure it runs.
2. Create a launch script, and ensure it runs GW2 from the command line (from
   Lutris, you would create it with `lutris guild-wars-2 --output-script
   gw2.sh`).
3. Backup your `GFXSettings.GW2-64.exe.xml` (from `<gw2
   WINEPREFIX>/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/`), run the game
   and set graphics to values you'd like to run multiple clients with (all
   minimums likely), then stash the modified `GFXSettings.GW2-64.exe.xml` and
   restore your nice one for regular use.
4. Download the script and make sure it's executable (`chmod +x <downloaded filename>`)
5. Run the script - for example `./gw2-alt.sh` to run it from the current
   directory. This will create a config file.
6. Edit the config.sh file created - ensure you provide the path to the GW2
   WINE prefix and all the environment variables required to run the game,
   copied from your working launch script from step 2.
7. Run the script again - this will create the runtime and data directories
8. Copy your stashed `GFXSettings.GW2-64.exe.xml` to the data directory.

### Setting up accounts

To set up an account, ensure no other accounts are running, then run `gw2-alt.sh
-o account-name`. Save the username and password, log in and launch the account
and change local settings however you'd like to keep them, then close the game
client. From now on you can launch that account as `gw2-alt.sh account-name`. If
you want to change local settings for that account again, you have to launch it
while no other accounts are running using the `-o` option again.

If you want a space in the account name, you must refer to it with quotes around
it every time, or it thinks you want to launch an account per word. This should
work - please let me know if you use it and run into problems.

### Running Accounts

### GW2 Configuration without Lutris

For a system without a Lutris install, I was able to run the game with the
following environment:

    export WINEARCH="win64"

    export WINEESYNC="1"
    export WINEFSYNC="1"
    export WINE_LARGE_ADDRESS_AWARE="1"

    export __GL_SHADER_DISK_CACHE="1"
    export __GL_SHADER_DISK_CACHE_PATH="$GW2_BASE_WINEPREFIX"
    export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

    # Save RAM - too chatty
    export DXVK_LOG_LEVEL="none"
    export WINEDEBUG="-all"

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
  bottleneck here. You probably won't be able to run as many accounts in
  parallel as in Windows, per one early user.
- Something else: check the log file for the account; they often have useful
  information to diagnose and fix issues.
- Client stuck on Downloading while launching: kill all running clients, all
  wine processes, all '.exe' processes, etc (`ps aux | grep '\.exe\|wine'`),
  then try launching them all again. Please let me know if you know how to
  prevent this; one user suggested putting `sudo` before `fuse-overlayfs` but I
  have not tested it yet.
- Can't unmount - "Device or resource busy": `lsof +D
  ~/.cache/gw2alts/account-name` then start killing things until it is no longer
  busy.
- Can't kill processes even with `kill -9`, computer sluggish, lots of disk io
  (`iotop`) w/o a process: you probably put the fuse-overlayfs on a different
  filesystem than the game was installed on. Sadly, you can only wait for the
  game files to copy over or reboot to interrupt the process.

### Core Idea

If you run into trouble, you can see if the basic idea works on your system
manually, to see if the core concept is causing trouble or the helpful
automation is wrong. The core steps the script does are:

To set up an account:
1. Create `upper-account-name` and `work-account-name` directories and run `fuse-overlayfs -o lowerdir="$GW2_BASE_WINEPREFIX" -o upperdir="upper-account-name" -o workdir="work-account-name" account-name`. This creates a [COW](https://en.wikipedia.org/wiki/Copy-on-write) clone of the GW2_BASE_WINEPREFIX which should remain tiny - `du -sh upper-account-name` to find out the true storage used. If it doesn't remain tiny, you may have launched a client without `-shareArchive`; it also appears putting fuse-overlayfs directories on a different device than the data also causes a full copy.
2. Back up your Local.dat from `$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat`, launch the game and set up the alt account the way you want it, copy the new Local.dat file somewhere like `account-name.dat` and restore your backed up `Local.dat` file.
3. Do the same for `GFXSettings.Gw2-64.exe.xml`, found in `$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/` - back up the original, set up graphics settings for the alts, save the new file elsewhere and restore the original
4. Copy the `GFXSettings.Gw2-64.exe.xml` to `account-name/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/` and `account-name.dat` file to `account-name/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat`. This overwrites only those files in the COW version of the game directory.
5. Launch the game with your normal command-line launcher script, except change the `WINEPREFIX` to be `account-name` instead of `$GW2_BASE_WINEPREFIX`, and you must pass the `-shareArchive` flag to GW2 or the game does a deep copy of the install since the game files are opened in exclusive mode. An example command: WINEPREFIX=account-name wine "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/Gw2-64.exe" -shareArchive -windowed

## License

This script is licensed under the terms of the WTFPL version 2.

If you submit any pull requests, you agree to license them under the same, to
avoid potential legal headaches I'd rather not deal with.
