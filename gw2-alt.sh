#!/bin/bash

GW2_FLAGS=""
WINE="wine"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gw2alts"

# TODO: I should probably use $XDG_CONFIG_HOME/gw2alts for the xml file, and
# $XDG_DATA_HOME for the individual Local.dat files; I can then run everything
# out of $XDG_CACHE_HOME.
# One problem is it would make it harder to see where files are, and harder to
# ensure Local.dat files are run from the same drive (for fast copies) as the
# game, and that the game runs on a fast drive.

if [ ! -f "$CONFIG_DIR/config.sh" ]; then
	cat << EOF
No configuration file detected.
Please create a configuration directory with:
  mkdir $CONFIG_DIR"
Then add a file named "config.sh" with the following lines:

exit 1
GW2_BASE_WINEPREFIX="<where Guild Wars 2 is - will have a dosdevices and drive_c subfolder>"
GW2_ALT_BASE="<where you want alts to store their information - don't forget to create it!>"
GW2_FLAGS="<what options you'd like to pass to Guild Wars 2 when it runs - see https://wiki.guildwars2.com/wiki/Command_line_arguments>"

Then change everything inside the quotes according to what it says it should be
and remove the line that says "exit 1"

You should also put in the config.sh any environment variables needed to run
the game just like you would find in a Lutris launch script. Each of those
lines should start with the word "export". If you need to not use the system
wine, you can set WINE to the path to your wine executable.

You can simply insert the whole "# Environment variables" block from the Lutris
launch script here.

For a non-Lutris install I use the following:

export WINEARCH="win64"

export WINEESYNC="1"
export WINEFSYNC="1"
export WINE_LARGE_ADDRESS_AWARE="1"

export __GL_SHADER_DISK_CACHE="1"
export __GL_SHADER_DISK_CACHE_PATH="\$GW2_BASE_WINEPREFIX"
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

# Save RAM - too chatty
export DXVK_LOG_LEVEL="none"
export WINEDEBUG="-all"
EOF
	exit 1
fi

# Don't lint the sourced file; dynamic location:
# shellcheck source=/dev/null
source "$CONFIG_DIR/config.sh"

if [[ ! "$(declare -p GW2_FLAGS 2>/dev/null)" =~ "declare -a" ]]; then
    read -ra GW2_FLAGS <<< "$GW2_FLAGS"
fi

GAME_EXE=$(basename "$(ls "$GW2_BASE_WINEPREFIX/drive_c/Program Files/Guild Wars 2/"*"-64.exe")")
GFX_FILE="GFXSettings.$GAME_EXE.xml"

# Create conf dir if not exists
if [ ! -d "$GW2_ALT_BASE/conf" ] || [ ! -f "$GW2_ALT_BASE/conf/$GFX_FILE" ]; then
	mkdir -p "$GW2_ALT_BASE/conf"
	echo "Please change graphics settings on your first launch to something you can run multiple of, then copy"
	echo "$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/$GFX_FILE"
	echo "to $GW2_ALT_BASE/conf"
	exit 1
fi

function help () {
	echo "GW2 Linux Multibox Launcher Script"
	echo
	echo "Syntax: $0 [-c|-u|-o|-n|-x|-d|-h] name ..."
	echo "options:"
	echo "c	Create the account"
	echo "u	Update the Local.dat for game updates before launching the alt. The main client must not be running. Also implies -n."
	echo "o	Run with the ability to make configuration changes - only one at at time"
	echo "n	Don't run the game client; just do the other operations"
	echo "x	Close the account"
	echo "d	Remove the account"
	echo "l	List set up accounts"
	echo "h	Show this help message"
	echo
	echo "Atypical Dependencies: fuse-overlayfs and xdotool, an already working GW2 launch script"
	# setsid is provided by util-linux, which also provides mount
	# pgrep is provided by procps-ng, which also provides ps
}

function list () {
	find "$GW2_ALT_BASE/conf" -iname '*.dat' | sort -h | xargs basename -s .dat | paste -sd' '
}

function setup () {
	# TODO: set up the general $GFX_FILE file
	# https://en-forum.guildwars2.com/topic/47337-how-to-manage-multiple-accounts-after-12219-patch/ has some instructions I could crib
	# See also https://wiki.guildwars2.com/wiki/Command_line_arguments/multiple_account_swapping

	if [ ! -d "$GW2_ALT_BASE/$1" ]; then
		mkdir -p "$GW2_ALT_BASE/work-$1" "$GW2_ALT_BASE/$1"

		# We have a template upper directory including file overrides; use it
		# TODO: document this, how to create by getting how you want then copying the upper dir, and removing unessential changes
		if test -d "$GW2_ALT_BASE/conf/upper"; then
			cp -a "$GW2_ALT_BASE/conf/upper" "$GW2_ALT_BASE/upper-$1"
		else
			mkdir "$GW2_ALT_BASE/upper-$1"
		fi

		fuse-overlayfs -o lowerdir="$GW2_BASE_WINEPREFIX" -o upperdir="$GW2_ALT_BASE/upper-$1" -o workdir="$GW2_ALT_BASE/work-$1" "$GW2_ALT_BASE/$1"
	fi

	cp "$GW2_ALT_BASE/conf/$GFX_FILE" "$GW2_ALT_BASE/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/"
	# check if the file exists first
	if test -f "$GW2_ALT_BASE/conf/$1.dat"; then
		cp "$GW2_ALT_BASE/conf/$1.dat" "$GW2_ALT_BASE/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
	fi
}

function runexclusive () {
	export WINEPREFIX="$GW2_BASE_WINEPREFIX"
	GW2CONF_DIR="$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2"

	local name="$1"
	shift
	local args=("$@")

	if test -f "$GW2CONF_DIR"/Local.dat; then
		mv "$GW2CONF_DIR"/Local.dat "$GW2CONF_DIR"/Local.dat.bak
	fi
	if test -f "$GW2_ALT_BASE/conf/$name.dat"; then
		cp "$GW2_ALT_BASE/conf/$name.dat" "$GW2CONF_DIR"/Local.dat
	fi

	"$WINE" "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/$GAME_EXE" "${args[@]}" &> "$GW2_ALT_BASE/$name".log

	mv "$GW2CONF_DIR"/Local.dat "$GW2_ALT_BASE/conf/$name.dat"
	if test -f "$GW2CONF_DIR"/Local.dat.bak; then
		cp "$GW2CONF_DIR"/Local.dat.bak "$GW2CONF_DIR"/Local.dat
	fi

	if test -d "$GW2_ALT_BASE/$name"; then
		cp "$GW2_ALT_BASE/conf/$name.dat" "$GW2_ALT_BASE/$name/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
	fi
}

function update () {
	runexclusive "$1" -image
}

function configure () {
	runexclusive "$1" "${GW2_FLAGS[@]}"
	cp "$GW2_ALT_BASE/conf/$1.dat" "$GW2_ALT_BASE/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
}

function run() {
	export WINEPREFIX="$GW2_ALT_BASE/$1"
	"$WINE" "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/$GAME_EXE" -shareArchive "${GW2_FLAGS[@]}" &> "$GW2_ALT_BASE/$1".log

	# Wait for the above to exit, then
	if test -f "$GW2_ALT_BASE/$1".pid; then
		rm "$GW2_ALT_BASE/$1".pid
	fi

	#killall CrGpuMain CrUtilityMain CrRendererMain start.exe explorer.exe GW2-64.exe
}

function runwithpid () {
	run "$1" &

	local sess
	sess=$(ps -o sess= $$)
	#echo "Session $sess"
	while true; do # TODO: put in a limit and print a warning if reached?
		#pid=$(ps -o pid=,comm= -s $sess | grep "$GAME_EXE" | awk '{ print $1 }')
		pid=$(pgrep -s "$sess" -f "$GAME_EXE")
		#echo "PID: $PID"
		if [[ -n "$pid" ]]; then
			echo "$pid" > "$GW2_ALT_BASE/$1".pid
			break
		fi
		sleep 1
	done
}

function getwindowhandle () {
	local pid
	pid=$(<"$GW2_ALT_BASE/$1".pid)
	return "$(xdotool search --all --onlyvisible --pid "$pid" --class "$GAME_EXE")"
}

function waitrun () {
	# TODO: put in an upper limit, and print a warning if reached?
	while [ ! -f "$GW2_ALT_BASE/$1".pid ]; do
		sleep 1
	done

	local handle geometry
	while [ -f "$GW2_ALT_BASE/$1".pid ]; do
		handle=$(getwindowhandle "$1")
		geometry=$(xdotool getwindowgeometry "$handle" | tail -n 1 | awk '{ print $2 }')
		# The geometry for the launcher window is fixed at 1120x976
		# XXX: if the user _happens_ to pick the same window size, this won't terminate
		if [ -n "$geometry" ] && [ "$geometry" != '1120x976' ]; then
			break
		fi
		#echo "$geometry"
		sleep 1
	done
}

function setname () {
	local handle name
	# xdotool - get window ID then name, mint issue, running on X11 though
	while [ -f "$GW2_ALT_BASE/$1".pid ]; do
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
	if [ ! -f "$GW2_ALT_BASE/$1".pid ]; then
		echo "$1 is not running"
		return 1
	fi
	handle=$(getwindowhandle "$1")
	xdotool windowquit "$handle"
}

function remove () {
	if [ ! -d "$GW2_ALT_BASE/$1" ]; then
		echo "$1 not found"
		return 1
	fi
	fusermount -u "$GW2_ALT_BASE/$1"
	rm -rf "$GW2_ALT_BASE/upper-$1" "$GW2_ALT_BASE/work-$1" "${GW2_ALT_BASE:?}/$1"
}

# Check if I'm launching the game in a setsid subshell
# Partial credit: https://stackoverflow.com/a/29107686/118153
me_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
me_FILE=$(basename "$0")
if [ "$1" == "run" ] ; then
	runwithpid "$2"
	exit 0
fi

OPT_UPDATE=
OPT_SETUP=
OPT_CONFIG=
OPT_REMOVE=
OPT_CLOSE=
OPT_RUN=1
while getopts "cuonxdlh" flag; do
	case $flag in
		c) OPT_SETUP=1;;
		u) OPT_UPDATE=1; OPT_RUN=;;
		o) OPT_CONFIG=1; OPT_RUN=;;
		n) OPT_RUN=;;
		x) OPT_CLOSE=1; OPT_RUN=;;
		d) OPT_REMOVE=1; OPT_RUN=;;
		l)
			list
			exit;;
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

while test $# -gt 0
do
	if [[ $OPT_SETUP ]]
	then
		echo "Creating $1"
		setup "$1"
	fi

	# Don't know why, but it works better if we rebuild after an update.
	if [[ $OPT_UPDATE ]]
	then
		echo "Updating $1"
		update "$1"
		remove "$1"
		setup "$1"
	fi

	if [[ $OPT_CONFIG ]]
	then
		echo "Running without -shareArchive to configure $1"
		configure "$1"
	fi

	if [[ $OPT_RUN ]]
	then
		if [ ! -d "$GW2_ALT_BASE/$1" ]; then
			echo "$1 not set up yet"
			exit 1
		fi
		echo "Running $1"
		setsid "$me_DIR"/"$me_FILE" run "$1" &
		waitrun "$1"
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
		echo "Removing $1"
		remove "$1"
	fi

	shift
done
