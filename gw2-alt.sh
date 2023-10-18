#!/bin/bash

GW2_FLAGS=""
WINE="wine"

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

# Create conf dir if not exists
if [ ! -d "$GW2_ALT_BASE/conf" ]; then
	mkdir -p "$GW2_ALT_BASE/conf"
	echo "Please change graphics settings on your first launch to something you can run multiple of, then copy"
	echo "$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/GFXSettings.GW2-64.exe.xml"
	echo "to $GW2_ALT_BASE/conf"
fi

function help () {
	echo "GW2 Linux Multibox Launcher Script"
	echo
	echo "Syntax: $0 [-u|-r|-m|-n|-c|-h] num ..."
	echo "options:"
	echo "u	Update the Local.dat for game updates before launching the alt. The main client must not be running. Also implies -r."
	echo "r	Recreate the fuse filesystem for the alt, to minimize space and deviation"
	echo "d	Remove the account"
	echo "m	Make the account"
	echo "o Run with the ability to make configuration changes - only one at at time"
	echo "n	Don't run the game client; just do the other operations"
	echo "c	Close the account"
	echo "h	Show this help message"
	echo
	echo "Atypical Dependencies: fuse-overlayfs, xdotool, setsid, already working GW2 launch scripts"
}

function setup () {
	# TODO: set up the general GFXSettings.GW2-64.exe.xml file
	# https://en-forum.guildwars2.com/topic/47337-how-to-manage-multiple-accounts-after-12219-patch/ has some instructions I could crib
	# See also https://wiki.guildwars2.com/wiki/Command_line_arguments/multiple_account_swapping

	mkdir -p "$GW2_ALT_BASE/upper-$1" "$GW2_ALT_BASE/work-$1" "$GW2_ALT_BASE/$1"
	fuse-overlayfs -o lowerdir=$GW2_BASE_WINEPREFIX -o upperdir="$GW2_ALT_BASE/upper-$1" -o workdir="$GW2_ALT_BASE/work-$1" "$GW2_ALT_BASE/$1"

	cp "$GW2_ALT_BASE/conf/GFXSettings.GW2-64.exe.xml" "$GW2_ALT_BASE/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/"
	# check if the file exists first
	if test -f "$GW2_ALT_BASE/conf/$1.dat"; then
		cp "$GW2_ALT_BASE/conf/$1.dat" "$GW2_ALT_BASE/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
	fi
}

function update () {
	export WINEPREFIX="$GW2_BASE_WINEPREFIX"
	GW2CONF_DIR="$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2"

	mv "$GW2CONF_DIR"/Local.dat "$GW2CONF_DIR"/Local.dat.bak
	cp "$GW2_ALT_BASE/conf/$1.dat" "$GW2CONF_DIR"/Local.dat

	"$WINE" "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/GW2-64.exe" -image &> "$GW2_ALT_BASE/$1".log

	mv "$GW2CONF_DIR"/Local.dat "$GW2_ALT_BASE/conf/$1.dat"
	cp "$GW2CONF_DIR"/Local.dat.bak "$GW2CONF_DIR"/Local.dat
}

function configure () {
	export WINEPREFIX="$GW2_BASE_WINEPREFIX"
	GW2CONF_DIR="$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2"

	if test -f "$GW2CONF_DIR"/Local.dat; then
		mv "$GW2CONF_DIR"/Local.dat "$GW2CONF_DIR"/Local.dat.bak
	fi
	cp "$GW2_ALT_BASE/conf/$1.dat" "$GW2CONF_DIR"/Local.dat

	"$WINE" "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/GW2-64.exe" $GW2_FLAGS &> "$GW2_ALT_BASE/$1".log

	mv "$GW2CONF_DIR"/Local.dat "$GW2_ALT_BASE/conf/$1.dat"
	if test -f "$GW2CONF_DIR"/Local.dat.bak; then
		cp "$GW2CONF_DIR"/Local.dat.bak "$GW2CONF_DIR"/Local.dat
	fi

	cp "$GW2_ALT_BASE/conf/$1.dat" "$GW2_ALT_BASE/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
}

function run() {
	export WINEPREFIX="$GW2_ALT_BASE/$1"
	"$WINE" "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/GW2-64.exe" -shareArchive $GW2_FLAGS &> "$GW2_ALT_BASE/$1".log

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
	while true; do
		pid=$(ps -o pid=,comm= -s $sess | grep GW2-64.exe | cut -d' ' -f 1)
		if [[ -n "$pid" ]]; then
			echo $pid > "$GW2_ALT_BASE/$1".pid
			break
		fi
		sleep 1
	done
}

function waitrun () {
	while true; do
		if test -f "$GW2_ALT_BASE/$1".pid; then
			pid=$(cat "$GW2_ALT_BASE/$1".pid)
			break
		fi
		sleep 1
	done

	while true; do
		if [ ! -f "$GW2_ALT_BASE/$1".pid ]; then
			exit 1
		fi
		geometry=$(xdotool search --all --onlyvisible --pid $(<"$GW2_ALT_BASE/$1".pid) --class GW2-64.exe getwindowgeometry | tail -n 1 | cut -d: -f 2)
		# fixed geometry for launcher window - 1120x976
		if [ -n "$geometry" ] && [ "$geometry" != " 1120x976" ]; then
			break
		fi
		sleep 1
	done
}

function setname () {
	while true; do
		name=$(xdotool search --all --onlyvisible --pid $(<"$GW2_ALT_BASE/$1".pid) --class GW2-64.exe getwindowname)
		if [ "$name" == "Guild Wars 2" ]; then
			xdotool search --all --onlyvisible --pid $(<"$GW2_ALT_BASE/$1".pid) --class GW2-64.exe set_window --name "Guild Wars 2 - $1"
			break
		fi
		sleep 1
	done
}

function close () {
	xdotool search --all --onlyvisible --pid $(<"$GW2_ALT_BASE/$1".pid) --class GW2-64.exe windowquit
}

function remove () {
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
OPT_REBUILD=
OPT_REMOVE=
OPT_CLOSE=
OPT_RUN=1
while getopts "urnmcohd" flag; do
	case $flag in
		u) OPT_UPDATE=1; OPT_REBUILD=1;;
		r) OPT_REBUILD=1;;
		d) OPT_REMOVE=1; OPT_RUN=;;
		n) OPT_RUN=;;
		m) OPT_SETUP=1; OPT_RUN=;;
		o) OPT_CONFIG=1; OPT_RUN=;;
		c) OPT_CLOSE=1; OPT_RUN=;;
		\?)
			echo "Error: Invalid option"
			help
			exit 1;;
		h)
			help
			exit;;
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

	# Don't know why, but it works better if we rebuild after an update,
	# instead of before
	if [[ $OPT_UPDATE ]]
	then
		echo "Updating $1"
		update "$1"
	fi

	if [[ $OPT_REBUILD ]]
	then
		echo "Rebuilding $1"
		remove "$1"
		setup "$1"
	fi

	if [[ $OPT_CONFIG ]]
	then
		echo "Running to configure $1"
		configure "$1" &
	fi

	if [[ $OPT_RUN ]]
	then
		echo "Running $1"
		setsid $me_DIR/$me_FILE run "$1" &
		waitrun "$1"
		setname "$1" &
	fi

	if [[ $OPT_CLOSE ]]
	then
		close "$1"
		echo "Closed $1"
	fi

	if [[ $OPT_REMOVE ]]
	then
		echo "Removing $1"
		remove "$1"
	fi

	shift
done