#!/bin/bash

# Quick check for some issues early users found
if [ "$0" = "bash" ]; then
	echo "This script does not work properly if you source it - please ensure it is executable via \`chmod +x gw2-alt.sh\` and run it via for example \`./gw2-alt.sh\`"
	exit 1
fi
if [ ! -f "/bin/bash" ]; then
	echo "This script expects to be run by bash. Please make sure it is installed on your system."
	exit 1
fi

# These are optionally overriden by the config.sh
GW2_FLAGS=()
WINE="wine" # default
GW2_ALT_RUNTIME_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/gw2alts"
GW2_ALT_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gw2alts"

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

# Replace the lines below this with all the environment variables needed to run
# GW2 - these come from your CLI launcher script. If you generated it via:
# \`lutris guild-wars-2 --output-script gw2.sh\`
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

GAME_EXE=$(basename "$(ls "$GW2_BASE_WINEPREFIX/drive_c/Program Files/Guild Wars 2/"*"-64.exe")")
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

Copying "$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/$GFX_FILE" to $GW2_ALT_DATA_DIR
If you would like to have special (eg, reduced) graphics settings when running multiple accounts, please backup your $GFX_FILE, launch the game and change your graphics to the multibox values, replace $GW2_ALT_DATA_DIR/$GFX_FILE with the updated file, and restore your previous $GFX_FILE
Alternatively, you can copy a previously prepared $GFX_FILE to $GW2_ALT_DATA_DIR/

EOF
	cp "$GW2_BASE_WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/$GFX_FILE" "$GW2_ALT_DATA_DIR"
fi

# support declaring flags as a string "" instead of an array ()
if [[ ! "$(declare -p GW2_FLAGS 2>/dev/null)" =~ "declare -a" ]]; then
    read -ra GW2_FLAGS <<< "$GW2_FLAGS"
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
	echo "Atypical Dependencies: fuse-overlayfs and xdotool, an already working GW2 launch script to reference"
	# setsid is provided by util-linux, which also provides mount
	# pgrep is provided by procps-ng, which also provides ps
}

function list () {
	echo "Accounts with a configured Local.dat:"
	local list
	list=$(find "$GW2_ALT_DATA_DIR" -iname '*.dat' | sort -h | xargs -r basename -s .dat | paste -sd' ')
	if [ -z "$list" ]; then
		echo "No accounts found. Set one up by running \`$0 -o account-name\`"
	else
		echo $list
	fi
}

function setup () {
	# TODO: set up the general $GFX_FILE file
	# https://en-forum.guildwars2.com/topic/47337-how-to-manage-multiple-accounts-after-12219-patch/ has some instructions I could crib
	# See also https://wiki.guildwars2.com/wiki/Command_line_arguments/multiple_account_swapping

	if [ ! -d "$GW2_ALT_RUNTIME_DIR/$1" ]; then
		echo "Preparing $1"

		mkdir -p "$GW2_ALT_RUNTIME_DIR/work-$1" "$GW2_ALT_RUNTIME_DIR/$1"

		# We have a template upper directory including file overrides; use it
		# TODO: document this, how to create by getting how you want then copying the upper dir, and removing unessential changes
		if test -d "$GW2_ALT_DATA_DIR/upper"; then
			cp -a "$GW2_ALT_DATA_DIR/upper" "$GW2_ALT_RUNTIME_DIR/upper-$1"
		else
			mkdir "$GW2_ALT_RUNTIME_DIR/upper-$1"
		fi

		fuse-overlayfs -o lowerdir="$GW2_BASE_WINEPREFIX" -o upperdir="$GW2_ALT_RUNTIME_DIR/upper-$1" -o workdir="$GW2_ALT_RUNTIME_DIR/work-$1" "$GW2_ALT_RUNTIME_DIR/$1"
	fi

	cp "$GW2_ALT_DATA_DIR/$GFX_FILE" "$GW2_ALT_RUNTIME_DIR/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/"
	# check if the file exists first
	if test -f "$GW2_ALT_DATA_DIR/$1.dat"; then
		cp "$GW2_ALT_DATA_DIR/$1.dat" "$GW2_ALT_RUNTIME_DIR/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
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
	if test -f "$GW2_ALT_DATA_DIR/$name.dat"; then
		cp "$GW2_ALT_DATA_DIR/$name.dat" "$GW2CONF_DIR"/Local.dat
	fi

	"$WINE" "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/$GAME_EXE" "${args[@]}" &> "$GW2_ALT_RUNTIME_DIR/$name".log

	mv "$GW2CONF_DIR"/Local.dat "$GW2_ALT_DATA_DIR/$name.dat"
	if test -f "$GW2CONF_DIR"/Local.dat.bak; then
		cp "$GW2CONF_DIR"/Local.dat.bak "$GW2CONF_DIR"/Local.dat
	fi

	if test -d "$GW2_ALT_RUNTIME_DIR/$name"; then
		cp "$GW2_ALT_DATA_DIR/$name.dat" "$GW2_ALT_RUNTIME_DIR/$name/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
	fi

	# No cleanup for run exclusive - lets configure upper template, and required to allow backup of Local.dat
}

function update () {
	echo "Updating $1"
	runexclusive "$1" -image
}

function configure () {
	runexclusive "$1" "${GW2_FLAGS[@]}"
	cp "$GW2_ALT_DATA_DIR/$1.dat" "$GW2_ALT_RUNTIME_DIR/$1/drive_c/users/$USER/AppData/Roaming/Guild Wars 2/Local.dat"
}

function run() {
	export WINEPREFIX="$GW2_ALT_RUNTIME_DIR/$1"
	"$WINE" "$WINEPREFIX/drive_c/Program Files/Guild Wars 2/$GAME_EXE" -shareArchive "${GW2_FLAGS[@]}" &> "$GW2_ALT_RUNTIME_DIR/$1".log

	# Wait for the above to exit, then
	if test -f "$GW2_ALT_RUNTIME_DIR/$1".pid; then
		rm "$GW2_ALT_RUNTIME_DIR/$1".pid
	fi

	sleep 1 # TODO need something less load/performance dependent
	remove "$1"

	#killall CrGpuMain CrUtilityMain CrRendererMain start.exe explorer.exe GW2-64.exe
}

function runwithpid () {
	run "$1" &

	local sess
	sess=$(ps -o sess= $$)
	#echo "Session $sess"
	while true; do # TODO: put in a limit and print a warning if reached?
		pid=$(ps -o pid=,comm= -s $sess | grep "$GAME_EXE" | awk '{ print $1 }')
		#pid=$(pgrep -s "$sess" -f "$GAME_EXE")
		#echo "PID: $PID"
		if [[ -n "$pid" ]]; then
			echo "$pid" > "$GW2_ALT_RUNTIME_DIR/$1".pid
			break
		fi
		sleep 1
	done
}

function getwindowhandle () {
	local pid
	pid=$(<"$GW2_ALT_RUNTIME_DIR/$1".pid)
	xdotool search --all --onlyvisible --pid "$pid" --class "$GAME_EXE"
}

function waitrun () {
	# TODO: put in an upper limit, and print a warning if reached?
	while [ ! -f "$GW2_ALT_RUNTIME_DIR/$1".pid ]; do
		sleep 1
	done

	local handle geometry
	while [ -f "$GW2_ALT_RUNTIME_DIR/$1".pid ]; do
		handle=$(getwindowhandle "$1")
		if [ ! -z "$handle" ]; then
			# Handle not empty - worth running the next command
			# TODO: don't run this if handle doesn't exist, say something more meaningful
			geometry=$(xdotool getwindowgeometry "$handle" | tail -n 1 | awk '{ print $2 }')
			# The geometry for the launcher window is fixed at 1120x976
			# XXX: if the user _happens_ to pick the same window size, this won't terminate
			if [ -n "$geometry" ] && [ "$geometry" != '1120x976' ]; then
				break
			fi
			#echo "$geometry"
		fi
		sleep 1
	done
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
	handle=$(getwindowhandle "$1")
	xdotool windowquit "$handle"
}

function remove () {
	if [ ! -d "$GW2_ALT_RUNTIME_DIR/$1" ]; then
		echo "$1 not found"
		return 1
	fi
	fusermount -u "$GW2_ALT_RUNTIME_DIR/$1"
	rm -rf "$GW2_ALT_RUNTIME_DIR/upper-$1" "$GW2_ALT_RUNTIME_DIR/work-$1" "${GW2_ALT_RUNTIME_DIR:?}/$1"
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
	if [[ $OPT_UPDATE || $OPT_CONFIG || $OPT_RUN ]]
	then
		setup "$1"
	fi

	# Don't know why, but it works better if we rebuild after an update.
	if [[ $OPT_UPDATE ]]
	then
		update "$1"
		# no need to remove explicitly anymore, implicit now
	fi

	if [[ $OPT_CONFIG ]]
	then
		echo "Running without -shareArchive to configure $1"
		configure "$1"
	fi

	if [[ $OPT_RUN ]]
	then
		if [ ! -d "$GW2_ALT_RUNTIME_DIR/$1" ]; then
			echo "$1 not set up yet" # shouldn't happen anymore
			exit 1
		fi
		# TODO: really need to consider UX. Should I just make myself
		# executable? Would that violate the principle of least astonishment?
		if [ ! -x "$me_DIR/$me_FILE" ]; then
			echo "$me_DIR/$me_FILE must be executable - \`chmod +x \"$me_DIR/$me_FILE\"\`"
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
		echo "Cleaning up $1"
		remove "$1"
	fi

	shift
done
