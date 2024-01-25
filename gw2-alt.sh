#!/bin/bash

GW2_FLAGS=""
WINE="wine"

# TODO: I should probably use $XDG_CONFIG_HOME/gw2alts for the xml file, and
# $XDG_DATA_HOME for the individual Local.dat files; I can then run everything
# out of $XDG_CACHE_HOME.
# One problem is it would make it harder to see where files are, and harder to
# ensure Local.dat files are run from the same drive (for fast copies) as the
# game, and that the game runs on a fast drive.

if [ ! -f "$XDG_CONFIG_HOME/gw2alts/config.sh" ]; then
	cat << EOF
No configuration file detected.
Please create a configuration directory with:
  mkdir $XDG_CONFIG_HOME/gw2alts"
Then add a file named "config.sh" with the following lines:

exit 1
GW2_BASE_WINEPREFIX="<where Guild Wars 2 is - will have a dosdevices and drive_c subfolder>"
GW2_ALT_BASE="<where you want alts to store their information - don't forget to create it!>"
GW2_FLAGS="<what options you'd like to pass to Guild Wars 2 when it runs>"

Then change everything inside the quotes according to what it says it should be
and remove the line that says "exit 1"

You should also put in that file any environment variables needed to run the
game just like you would find in a Lutris launch script. Each of those lines
should start with the word "export". If you need to not use the system wine,
you can set WINE to the path to your wine executable.

I use at least the following:

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

source "$XDG_CONFIG_HOME/gw2alts/config.sh"

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
	echo "Syntax: $0 [-c|-u|-o|-n|-x|-d|-h] num ..."
	echo "options:"
	echo "c	Create the account"
	echo "u	Update the Local.dat for game updates before launching the alt. The main client must not be running. Also implies -n."
	echo "o Run with the ability to make configuration changes - only one at at time"
	echo "n	Don't run the game client; just do the other operations"
	echo "x	Close the account"
	echo "d	Remove the account"
	echo "h	Show this help message"
	echo
	echo "Atypical Dependencies: fuse-overlayfs, xdotool, setsid, already working GW2 launch scripts"
}

function setup () {
	# TODO: set up the general $GFX_FILE file
	# https://en-forum.guildwars2.com/topic/47337-how-to-manage-multiple-accounts-after-12219-patch/ has some instructions I could crib
	# See also https://wiki.guildwars2.com/wiki/Command_line_arguments/multiple_account_swapping

	if [ ! -d "$GW2_ALT_BASE/$1" ]; then
		mkdir -p "$GW2_ALT_BASE/upper-$1" "$GW2_ALT_BASE/work-$1" "$GW2_ALT_BASE/$1"
		fuse-overlayfs -o lowerdir=$GW2_BASE_WINEPREFIX -o upperdir="$GW2_ALT_BASE/upper-$1" -o workdir="$GW2_ALT_BASE/work-$1" "$GW2_ALT_BASE/$1"
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

	if test -f "$GW2CONF_DIR"/Local.dat; then
		mv "$GW2CONF_DIR"/Local.dat "$GW2CONF_DIR"/Local.dat.bak
	fi
	if test -f "$GW2_ALT_BASE/conf/$1.dat"; then
		cp "$GW2_ALT_BASE/conf/$1.dat" "$GW2CONF_DIR"/Local.dat
	fi

	"$WINE" "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/$GAME_EXE" $2 &> "$GW2_ALT_BASE/$1".log

	mv "$GW2CONF_DIR"/Local.dat "$GW2_ALT_BASE/conf/$1.dat"
	if test -f "$GW2CONF_DIR"/Local.dat.bak; then
		cp "$GW2CONF_DIR"/Local.dat.bak "$GW2CONF_DIR"/Local.dat
	fi

	if test -d "$GW2_ALT_BASE/$1"; then
		cp "$GW2_ALT_BASE/conf/$1.dat" "$GW2_ALT_BASE/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
	fi
}

function update () {
	runexclusive "$1" -image
}

function configure () {
	runexclusive "$1" "$GW2_FLAGS"
	cp "$GW2_ALT_BASE/conf/$1.dat" "$GW2_ALT_BASE/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
}

function run() {
	export WINEPREFIX="$GW2_ALT_BASE/$1"
	"$WINE" "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/$GAME_EXE" -shareArchive $GW2_FLAGS &> "$GW2_ALT_BASE/$1".log

	# Wait for the above to exit, then
	if test -f "$GW2_ALT_BASE/$1".pid; then
		rm "$GW2_ALT_BASE/$1".pid
	fi

	#killall CrGpuMain CrUtilityMain CrRendererMain start.exe explorer.exe GW2-64.exe
}

function runwithpid () {
	run "$1" &

	sess=$(ps -o sess= $$)
	#echo "Session $sess"
	while true; do # TODO: put in a limit and print a warning if reached?
		pid=$(ps -o pid=,comm= -s $sess | grep "$GAME_EXE" | awk '{ print $1 }')
		#echo "PID: $PID"
		if [[ -n "$pid" ]]; then
			echo $pid > "$GW2_ALT_BASE/$1".pid
			break
		fi
		sleep 1
	done
}

function waitrun () {
	# TODO: put in an upper limit, and print a warning if reached?
	while [ ! -f "$GW2_ALT_BASE/$1".pid ]; do
		sleep 1
	done

	while [ -f "$GW2_ALT_BASE/$1".pid ]; do
		geometry=$(xdotool search --all --onlyvisible --pid $(<"$GW2_ALT_BASE/$1".pid) --class "$GAME_EXE" getwindowgeometry | tail -n 1 | awk '{ print $2 }')
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
	while [ -f "$GW2_ALT_BASE/$1".pid ]; do
		name=$(xdotool search --all --onlyvisible --pid $(<"$GW2_ALT_BASE/$1".pid) --class "$GAME_EXE" getwindowname)
		if [ "$name" == "Guild Wars 2" ]; then
			xdotool search --all --onlyvisible --pid $(<"$GW2_ALT_BASE/$1".pid) --class "$GAME_EXE" set_window --name "Guild Wars 2 - $1"
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
	xdotool search --all --onlyvisible --pid $(<"$GW2_ALT_BASE/$1".pid) --class "$GAME_EXE" windowquit
}

function remove () {
	if [ ! -d "$GW2_ALT_BASE/$1" ]; then
		echo "$1 not found"
		return 1
	fi
	fusermount -u "$GW2_ALT_BASE/$1"
	rm -rf "$GW2_ALT_BASE/upper-$1" "$GW2_ALT_BASE/work-$1" "$GW2_ALT_BASE/$1"
}

# Check if I'm launching the game in a setsid subshell
# Partial credit: https://stackoverflow.com/a/29107686/118153
me_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
me_FILE=$(basename $0)
if [ "$1" == "run" ] ; then
	runwithpid $2
	exit 0
fi

OPT_UPDATE=
OPT_SETUP=
OPT_CONFIG=
OPT_REMOVE=
OPT_CLOSE=
OPT_RUN=1
while getopts "cuonxdh" flag; do
	case $flag in
		c) OPT_SETUP=1;;
		u) OPT_UPDATE=1; OPT_RUN=;;
		o) OPT_CONFIG=1; OPT_RUN=;;
		n) OPT_RUN=;;
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

shift $(($OPTIND - 1))

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
		setsid $me_DIR/$me_FILE run "$1" &
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
