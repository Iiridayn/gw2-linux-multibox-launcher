#!/bin/bash

# Quick check for some issues early users found
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
	echo "This script does not work properly if you source it - please ensure it is executable via \`chmod +x gw2-alt.sh\` and run it via for example \`./gw2-alt.sh\`"
	return 1
fi
if [ -z "$BASH_VERSION" ]; then
	echo "This script expects to be run by bash. Please make sure it is installed on your system."
	exit 1
fi

# These are optionally overriden by the config.sh
GW2_FLAGS=()
WINE="wine" # default
GW2_ALT_RUNTIME_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/gw2alts"
GW2_ALT_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gw2alts"
GW2_WINE_INSTALL_PATH="drive_c/Program Files/Guild Wars 2" # default
GW2_WINE_USER="$USER"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gw2alts"

if [ ! -d "$CONFIG_DIR" ]; then
	echo "First run. Creating $CONFIG_DIR"
	mkdir -p "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_DIR/config.sh" ]; then
	echo "Creating $CONFIG_DIR/config.sh"
	cat > "$CONFIG_DIR/config.sh" << EOF
# Set this to the path to where the GW2 WINE prefix is located. If you
# installed GW2 via Lutris, this would be "~/Games/guild-wars-2"
export GW2_BASE_WINEPREFIX=""
# see https://wiki.guildwars2.com/wiki/Command_line_arguments for options
#export GW2_FLAGS=(-autologin -mapLoadinfo -nosound -windowed)
export GW2_FLAGS=()
# Optionally set where Local.dat and the graphics xml files will be stored
#export GW2_ALT_DATA_DIR="$GW2_ALT_DATA_DIR"
# Optionally set where the mountpoints and log files will be created
#export GW2_ALT_RUNTIME_DIR="$GW2_ALT_RUNTIME_DIR"
# Optionally cap the RAM per process to ease RAM pressure when running several accounts
# This does also require systemd-run, systemd.unified_cgroup_hierarchy=1
# (probably default), and systemd configured to deletegate memory to cgroups
# (also probably default)
#export GW2_MEMORY_MAX="4G"
#export GW2_MEMORY_HIGH="3G"

# Replace the lines below this with all the environment variables needed to run
# GW2 - these come from your CLI launcher script. If you generated it via:
# \`lutris --output-script guild-wars-2\`
# You would copy the entire block that starts with
# # Environment Variables
# here, but not the "Working Directory" or "Command" lines - this script is
# responsible for running the command.
# Each line is expected to start with "export"

echo "Please update \\"$CONFIG_DIR/config.sh\\" so it knows how to run GW2";
exit 1
EOF
	cat << EOF

Please edit this file as directed in the comments so this script knows where to
find GW2 and how to run it.
EOF
	exit 1
fi

# Don't lint the sourced file; dynamic location:
# shellcheck source=/dev/null
source "$CONFIG_DIR/config.sh"

if [ -z "$GW2_BASE_WINEPREFIX" ] || [ ! -d "$GW2_BASE_WINEPREFIX" ]; then
	echo "Please do not skip setup steps or this launcher will not function. You need to edit \"$CONFIG_DIR/config.sh\" and set \$GW2_BASE_WINEPREFIX to the path to the WINE prefix GW2 was installed in."
	exit 1
fi

# Migrate previous config
if [ -n "$GW2_ALT_BASE" ]; then
	cat << EOF
Please remove \$GW2_ALT_BASE in $CONFIG_DIR/config.sh. To keep the same data
directories as before replace with the following lines:

export GW2_ALT_DATA_DIR="$GW2_ALT_BASE/conf"
export GW2_ALT_RUNTIME_DIR="$GW2_ALT_BASE"
EOF
	exit 1
fi

# Variables derived from others set
GW2_APPDATA_PATH="drive_c/users/$GW2_WINE_USER/AppData/Roaming/Guild Wars 2"
GW2_BASE_APPDATA="$GW2_BASE_WINEPREFIX/$GW2_APPDATA_PATH"

# Figure out the executable name; I've seen GW2-64.exe and Gw2-64.exe; windows
# is by default case-insensitive, so the change wasn't a problem there.
if [ ! -d "$GW2_BASE_WINEPREFIX/$GW2_WINE_INSTALL_PATH" ]; then
	echo "Cannot find the GW2 executable. Please configure GW2_WINE_INSTALL_PATH."
	exit 1
fi
exes=("$GW2_BASE_WINEPREFIX/$GW2_WINE_INSTALL_PATH/"*"-64.exe")
if [[ ! -e "${exes[0]}" ]]; then
	echo "Cannot find the GW2 executable. Please configure GW2_WINE_INSTALL_PATH."
	exit 1
fi
GAME_EXE=$(basename "${exes[0]}")

GFX_FILE="GFXSettings.$GAME_EXE.xml"

function get_drive () {
	df -P "$1" | awk 'END{print $1}'
}
# Create dirs if not exist
if [ ! -d "$GW2_ALT_RUNTIME_DIR" ]; then
	echo "Runtime directory not found. Creating $GW2_ALT_RUNTIME_DIR"
	mkdir -p "$GW2_ALT_RUNTIME_DIR"
fi
if [ "$(get_drive "$GW2_BASE_WINEPREFIX")" != "$(get_drive "$GW2_ALT_RUNTIME_DIR")" ]; then
	echo
	echo "ERROR: The runtime directory is not on the same device as where the game is installed. This results in a very slow uninterruptable full copy of game files."
	echo "You can set \$GW2_ALT_RUNTIME_DIR in $CONFIG_DIR/config.sh to change this path"
	echo
	rm -r "$GW2_ALT_RUNTIME_DIR" # should be safe to wipe; put in XDG_CACHE_HOME for that reason
	echo "Removed $GW2_ALT_RUNTIME_DIR"
	exit 1
fi
if [ ! -d "$GW2_ALT_DATA_DIR" ]; then
	echo "Data directory not found. Creating $GW2_ALT_DATA_DIR"
	mkdir -p "$GW2_ALT_DATA_DIR"

	cat << EOF

Copying "$GW2_BASE_WINEPREFIX/$GW2_APPDATA_PATH/$GFX_FILE" to $GW2_ALT_DATA_DIR
If you would like to have special (eg, reduced) graphics settings when running multiple accounts, please backup your $GFX_FILE, launch the game and change your graphics to the multibox values, replace $GW2_ALT_DATA_DIR/$GFX_FILE with the updated file, and restore your previous $GFX_FILE
Alternatively, you can copy a previously prepared $GFX_FILE to $GW2_ALT_DATA_DIR/

EOF
	cp "$GW2_BASE_WINEPREFIX/$GW2_APPDATA_PATH/$GFX_FILE" "$GW2_ALT_DATA_DIR"
fi

# Should be after the block above that creates GW2_ALT_RUNTIME_DIR
LOCKFILE="$GW2_ALT_RUNTIME_DIR/using_base_install.lock"
if test -f "$LOCKFILE"; then
	echo "A configuration or update is already running (PID $(cat "$LOCKFILE" 2>/dev/null)). If it is not:"
	echo "  Salvage account data: cp \"$GW2_BASE_APPDATA/Local.dat\" \"$GW2_ALT_DATA_DIR/<account>.dat\""
	echo "  Restore base config:  mv \"$GW2_BASE_APPDATA/Local.dat.bak\" \"$GW2_BASE_APPDATA/Local.dat\""
	echo "Then delete $LOCKFILE and try again."
	exit 1
fi

# support declaring flags as a string "" instead of an array ()
if [[ ! "$(declare -p GW2_FLAGS 2>/dev/null)" =~ "declare -a" ]]; then
	# shellcheck disable=SC2128
	read -ra GW2_FLAGS <<< "$GW2_FLAGS"
fi

MEMORY_LIMIT_CMD=()
if [ -n "$GW2_MEMORY_MAX" ] && command -v systemd-run &>/dev/null; then
	_uid_cgroup="/sys/fs/cgroup/user.slice/user-$(id -u).slice"
	if [ -f "$_uid_cgroup/memory.max" ]; then
		MEMORY_LIMIT_CMD=(systemd-run --user --scope --slice gw2-alts -p "MemoryMax=$GW2_MEMORY_MAX")
		[ -n "$GW2_MEMORY_HIGH" ] && MEMORY_LIMIT_CMD+=(-p "MemoryHigh=$GW2_MEMORY_HIGH")
	else
		echo "Warning: GW2_MEMORY_MAX set but cgroup memory controller not delegated to user scope; running without memory limit"
	fi
fi

# Setup done - from here is the runtime section

function help () {
	echo "GW2 Linux Multibox Launcher Script"
	echo
	echo "Syntax: $0 [-u|-o|-x|-d|-h] name ..."
	echo
	echo "Listing accounts without options runs them; giving no options or accounts lists accounts."
	echo
	echo "options:"
	echo "u	Update the account Local.dat for game updates; updates one at a time and does not run the game"
	echo "o	Run with the ability to make configuration changes - only one account at a time"
	echo "x	Close the listed accounts"
	echo "d	Clean up the mount point for the listed accounts"
	echo "h	Show this help message"
	echo
	echo "Atypical Dependencies: fuse-overlayfs, xdotool, and xprop, an already working GW2 launch script to reference"
	# setsid is provided by util-linux, which also provides mount
	# pgrep is provided by procps-ng, which also provides ps
}

function list () {
	echo "Accounts with a configured Local.dat:"
	local list
	list=$(find "$GW2_ALT_DATA_DIR" -maxdepth 1 -iname '*.dat' | sort -h | xargs -r basename -s .dat | paste -sd' ')
	if [ -z "$list" ]; then
		echo "No accounts found. Set one up by running \`$0 -o account-name\`"
	else
		echo "$list"
	fi
}

function setup () {
	# TODO: set up the general $GFX_FILE file
	# https://en-forum.guildwars2.com/topic/47337-how-to-manage-multiple-accounts-after-12219-patch/ has some instructions I could crib
	# See also https://wiki.guildwars2.com/wiki/Command_line_arguments/multiple_account_swapping

	if [ ! -d "$GW2_ALT_RUNTIME_DIR/$1" ]; then
		echo "Preparing $1"

		mkdir -p "$GW2_ALT_RUNTIME_DIR/upper-$1" "$GW2_ALT_RUNTIME_DIR/work-$1" "$GW2_ALT_RUNTIME_DIR/$1"

		fuse-overlayfs -o lowerdir="$GW2_BASE_WINEPREFIX" -o upperdir="$GW2_ALT_RUNTIME_DIR/upper-$1" -o workdir="$GW2_ALT_RUNTIME_DIR/work-$1" "$GW2_ALT_RUNTIME_DIR/$1"
		local rc=$?
		if [[ $rc -ne 0 ]]; then
			echo "Error: fuse-overlayfs failed to mount overlay for $1"
			rm -rf "$GW2_ALT_RUNTIME_DIR/upper-$1" "$GW2_ALT_RUNTIME_DIR/work-$1" "${GW2_ALT_RUNTIME_DIR:?}/$1"
			exit 1
		fi
	fi

	# Apply addon override files, if any
	if test -d "$GW2_ALT_DATA_DIR/_addons"; then
		mkdir -p "$GW2_ALT_RUNTIME_DIR/$1/$GW2_WINE_INSTALL_PATH/addons"
		cp -a "$GW2_ALT_DATA_DIR/_addons/." "$GW2_ALT_RUNTIME_DIR/$1/$GW2_WINE_INSTALL_PATH/addons/"
	fi

	cp "$GW2_ALT_DATA_DIR/$GFX_FILE" "$GW2_ALT_RUNTIME_DIR/$1/$GW2_APPDATA_PATH/"
	# check if the file exists first
	if test -f "$GW2_ALT_DATA_DIR/$1.dat"; then
		cp "$GW2_ALT_DATA_DIR/$1.dat" "$GW2_ALT_RUNTIME_DIR/$1/$GW2_APPDATA_PATH/Local.dat"
	fi
}

function _runexclusive_interrupted () {
	if test -f "$GW2_BASE_APPDATA/Local.dat.bak"; then
		mv "$GW2_BASE_APPDATA/Local.dat.bak" "$GW2_BASE_APPDATA/Local.dat"
	fi
	rm -f "$LOCKFILE"
	echo "Base game installation restored (interrupted)"
}

# Only print the warning once at start, and restored message once at end, to avoid log spam
_runexclusive_warned=
_runexclusive_final=
# Run, using the original installation
function runexclusive () {
	if [[ -z "$_runexclusive_warned" ]]; then
		echo "Warning: base game installation temporarily in use. Do not launch the game by other means until this completes."
		_runexclusive_warned=1
	fi
	echo $$ > "$LOCKFILE"
	trap '_runexclusive_interrupted; exit 1' INT TERM

	export WINEPREFIX="$GW2_BASE_WINEPREFIX"

	local name="$1"
	shift
	local args=("$@")

	if test -f "$GW2_BASE_APPDATA"/Local.dat; then
		mv "$GW2_BASE_APPDATA"/Local.dat "$GW2_BASE_APPDATA"/Local.dat.bak
	fi
	if test -f "$GW2_ALT_DATA_DIR/$name.dat"; then
		cp "$GW2_ALT_DATA_DIR/$name.dat" "$GW2_BASE_APPDATA"/Local.dat
	fi

	# Wait for this to return
	"$WINE" "$WINEPREFIX/$GW2_WINE_INSTALL_PATH/$GAME_EXE" "${args[@]}" &> "$GW2_ALT_RUNTIME_DIR/$name".log
	local game_rc=$?
	if [[ $game_rc -ne 0 ]]; then
		echo "Warning: $name exited with code $game_rc — retrying once"
		"$WINE" "$WINEPREFIX/$GW2_WINE_INSTALL_PATH/$GAME_EXE" "${args[@]}" &>> "$GW2_ALT_RUNTIME_DIR/$name".log
		game_rc=$?
	fi

	if test -f "$GW2_BASE_APPDATA"/Local.dat; then
		mv "$GW2_BASE_APPDATA"/Local.dat "$GW2_ALT_DATA_DIR/$name.dat"
	else
		echo "Warning: account setup for '$name' failed — the game probably crashed. Please ensure the game runs normally, then try setting up with -o again."
	fi
	if test -f "$GW2_BASE_APPDATA"/Local.dat.bak; then
		cp "$GW2_BASE_APPDATA"/Local.dat.bak "$GW2_BASE_APPDATA"/Local.dat
	fi

	# If there is a set up mount for that account, copy the updated .dat file there too
	if test -d "$GW2_ALT_RUNTIME_DIR/$name"; then
		cp "$GW2_ALT_DATA_DIR/$name.dat" "$GW2_ALT_RUNTIME_DIR/$name/$GW2_APPDATA_PATH/Local.dat"
	fi

	rm -f "$LOCKFILE"
	trap - INT TERM
	[[ -n "$_runexclusive_final" ]] && echo "Base game installation restored"
	# No other cleanup: we didn't create an overlay
	return $game_rc
}

function update () {
	echo "Updating $1"
	runexclusive "$1" -image
}

function configure () {
	runexclusive "$1" "${GW2_FLAGS[@]}"
}

function run() {
	export WINEPREFIX="$GW2_ALT_RUNTIME_DIR/$1"
	local launch=("${MEMORY_LIMIT_CMD[@]}")
	[[ ${#launch[@]} -gt 0 ]] && launch+=(--unit "gw2-$1" --)
	setsid "${launch[@]}" "$WINE" "$WINEPREFIX/$GW2_WINE_INSTALL_PATH/$GAME_EXE" -shareArchive "${GW2_FLAGS[@]}" &> "$GW2_ALT_RUNTIME_DIR/$1".log &
	local wine_sess
	wine_sess=$(ps -o sess= -p $! | tr -d ' ')

	local pid count=0
	while true; do
		pid=$(pgrep -s "$wine_sess" -ix "$GAME_EXE" 2>/dev/null | head -1)
		if [[ -n "$pid" ]]; then
			break
		fi
		count=$((count + 1))
		if [[ $count -ge 30 ]]; then
			echo "Error: timed out waiting for $GAME_EXE to launch" >&2
			remove "$1"
			exit 1
		fi
		sleep 1
	done
	echo "$pid" > "$GW2_ALT_RUNTIME_DIR/$1".pid
	echo "Launched $1"

	WINEPREFIX="$GW2_ALT_RUNTIME_DIR/$1" wineserver --wait

	rm -f "$GW2_ALT_RUNTIME_DIR/$1".pid
	remove "$1"
}

function getwindowhandle () {
	[ -f "$GW2_ALT_RUNTIME_DIR/$1".pid ] || return 1
	local pid
	pid=$(<"$GW2_ALT_RUNTIME_DIR/$1".pid)
	xdotool search --all --onlyvisible --pid "$pid" | head -1
}

function waitrun () {
	while [ ! -f "$GW2_ALT_RUNTIME_DIR/$1".pid ]; do
		if ! kill -0 "$2" 2>/dev/null; then
			return 1
		fi
		sleep 1
	done

	local handle hints min_size max_size count=0
	while [ -f "$GW2_ALT_RUNTIME_DIR/$1".pid ]; do
		handle=$(getwindowhandle "$1")
		if [ -n "$handle" ]; then
			hints=$(xprop -id "$handle" WM_NORMAL_HINTS 2>/dev/null)
			min_size=$(echo "$hints" | grep 'minimum size' | grep -oE '[0-9]+ by [0-9]+')
			max_size=$(echo "$hints" | grep 'maximum size' | grep -oE '[0-9]+ by [0-9]+')
			# Launcher is fixed-size (min==max); game client is resizable (no max, or min!=max)
			if [ -z "$max_size" ] || [ "$min_size" != "$max_size" ]; then
				break
			fi
		fi
		count=$((count + 1))
		if [[ $count -ge 120 ]]; then
			echo "Error: timed out waiting for $1 to finish loading" >&2
			return 1
		fi
		sleep 1
	done

	echo "Loaded $1"
}

function setname () {
	local handle name
	# xdotool - get window ID then name, mint issue, running on X11 though
	while [ -f "$GW2_ALT_RUNTIME_DIR/$1".pid ]; do
		handle=$(getwindowhandle "$1")
		name=$(xdotool getwindowname "$handle")
		if [ "$name" == "Guild Wars 2" ]; then
			xdotool set_window --name "Guild Wars 2 - $1" "$handle"
			break
		fi
		sleep 1
	done
}

function close () {
	if [ ! -f "$GW2_ALT_RUNTIME_DIR/$1".pid ]; then
		echo "$1 is not running"
		return 1
	fi
	local pid count=0
	pid=$(<"$GW2_ALT_RUNTIME_DIR/$1".pid)
	kill -INT "$pid"
	until ! kill -0 "$pid" 2>/dev/null; do
		count=$((count + 1))
		if [[ $count -ge 30 ]]; then
			echo "Warning: $1 did not exit after ${count}s, force-killing"
			break
		fi
		sleep 1
	done
	WINEPREFIX="$GW2_ALT_RUNTIME_DIR/$1" wineserver -k
}

function remove () {
	if [ ! -d "$GW2_ALT_RUNTIME_DIR/$1" ]; then
		echo "$1 not found"
		return 1
	fi
	WINEPREFIX="$GW2_ALT_RUNTIME_DIR/$1" wineserver -k
	local count=0
	until fusermount -u "$GW2_ALT_RUNTIME_DIR/$1" 2>>"$GW2_ALT_RUNTIME_DIR/$1".log; do
		count=$((count + 1))
		if [[ $count -ge 30 ]]; then
			echo "Warning: could not unmount overlay for $1 after ${count}s. Please kill the hanging processes, then run \`gw2-alt.sh -d $1\` to retry."
			return 1
		fi
		sleep 1
	done
	rm -rf "$GW2_ALT_RUNTIME_DIR/upper-$1" "$GW2_ALT_RUNTIME_DIR/work-$1" "${GW2_ALT_RUNTIME_DIR:?}/$1"
}


OPT_UPDATE=
OPT_CONFIG=
OPT_REMOVE=
OPT_CLOSE=
OPT_RUN=1
while getopts "uoxdh" flag; do
	case $flag in
		u) OPT_UPDATE=1; OPT_RUN=;;
		o) OPT_CONFIG=1; OPT_RUN=;;
		x) OPT_CLOSE=1; OPT_RUN=;;
		d) OPT_REMOVE=1; OPT_RUN=;;
		h)
			help
			exit;;
		\?)
			echo "Error: Invalid option"
			help
			exit 1;;
	esac
done
shift $((OPTIND - 1))

if [ $# == 0 ]; then
	list
fi

while test $# -gt 0
do
	# _ gives me a reserved namespace in case all files are dumped together
	# Might seem hypothetical, but witnessed in practice.
	# If you already had one with _ at the start, can rename it
	if [[ "$1" == _* ]]; then
		echo "Skipping $1: account names may not start with _"
		shift
		continue
	fi

	# Don't know why, but it works better if we rebuild after an update.
	if [[ $OPT_UPDATE ]]
	then
		[[ $# -eq 1 ]] && _runexclusive_final=1
		if ! update "$1"; then
			echo "Warning: update of $1 failed after retry"
		fi
	fi

	if [[ $OPT_CONFIG ]]
	then
		_runexclusive_final=1
		echo "Configuring $1"
		configure "$1"
	fi

	if [[ $OPT_RUN ]]
	then
		setup "$1"
		if [ ! -d "$GW2_ALT_RUNTIME_DIR/$1" ]; then
			echo "$1 not set up yet" # shouldn't happen anymore
			exit 1
		fi
		echo "Running $1"
		run "$1" &
		run_pid=$!
		waitrun "$1" "$run_pid" || exit 1
		setname "$1" &
	fi

	if [[ $OPT_CLOSE ]]
	then
		if close "$1"; then
			echo "Closed $1"
		fi
	fi

	if [[ $OPT_REMOVE ]]
	then
		echo "Cleaning up $1"
		remove "$1"
	fi

	shift
done
