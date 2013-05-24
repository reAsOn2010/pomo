#!/bin/bash

# Copyright (c) 2013, James Spencer.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#--- Configuration (can be set via environment variables ---

[[ -n $POMO_FILE ]] && POMO=$POMO_FILE || POMO=$HOME/.local/share/pomo

[[ -n $POMO_WORK_TIME ]] && WORK_TIME=$POMO_WORK_TIME || WORK_TIME=1
[[ -n $POMO_BREAK_TIME ]] && BREAK_TIME=$POMO_BREAK_TIME || BREAK_TIME=1

#--- Pomodoro functions ---

function pomo_start {
    # Start new pomo block (work+break cycle).
    test -e $(dirname $POMO) || mkdir $(dirname $POMO)
    touch $POMO
}

function pomo_stop {
    # Stop pomo cycles.
    rm -f $POMO
}

function pomo_pause {
    # Pause a pomo block.
    running=$(pomo_stat)
    echo $running > $POMO
}

function pomo_ispaused {
    # Return 0 if paused, 1 otherwise.
    [[ $(wc -l $POMO | cut -d" " -f1) -gt 0 ]]
    return $?
}

function pomo_restart {
    # Restart a paused pomo block by updating the time stamp of the POMO file.
    running=$(pomo_stat)
    mtime=$(date --date "$(date) - $running seconds" +%m%d%H%M.%S)
    echo > $POMO # erase saved time stamp.
    touch -m -t $mtime $POMO
}

function pomo_update {
    # Update the time stamp on POMO a new cycle has started.
    running=$(pomo_stat)
    block_time=$(( (WORK_TIME+BREAK_TIME)*60 ))
    if [[ $running -gt $block_time ]]; then
        ago=$((running - block_time))
        mtime=$(date --date "$(date) - $ago seconds" +%m%d%H%M.%S)
        touch -m -t $mtime $POMO
    fi
}

function pomo_stat {
    # Return number of seconds since start of pomo block (work+break cycle).
    [[ -e $POMO ]] && running=$(cat $POMO) || running=0
    if [[ -z $running ]]; then
        pomo_start=$(stat -c +%Y $POMO)
        now=$(date +%s)
        running=$((now-pomo_start))
    fi
    echo $running
}

function pomo_clock {
    # Print out how much time is remaining in block.
    # WMM:SS indicates MM:SS left in the work block.
    # BMM:SS indicates MM:SS left in the break block.
    if [[ -e $POMO ]]; then
        pomo_update
        running=$(pomo_stat)
        left=$(( WORK_TIME*60 - running ))
        if [[ $left -lt 0 ]]; then
            left=$(( left + BREAK_TIME*60 ))
            prefix=B
        else
            prefix=W
        fi
        pomo_ispaused && prefix=P$prefix
        min=$(( left / 60 ))
        sec=$(( left - 60*min ))
        printf "%2s%02d:%02d" $prefix $min $sec
    else
        printf "  --:--"
    fi
}

function pomo_usage {
    # Print out usage message.
    cat <<END
pomo.sh [-h] [start | stop | pause | restart | clock | usage]

pomo.sh - a simple Pomodoro timer.

Options:

-h
    Print this usage message.

Actions:

start
    Start Pomodoro timer.
stop
    Stop Pomodoro timer.
pause
    Pause Pomodoro timer.
restart
    Restart a paused Pomodoro timer.
clock
    Print how much time (minutes and seconds) is remaining in the current
    Pomodoro cycle.  A prefix of B indicates a break period, a prefix of
    W indicates a work period and a prefix of P indicates the current period is
    paused.
usage
    Print this usage message.

Environment variables:

POMO_FILE
    Location of the Pomodoro file used to store the duration of the Pomodoro
    period (mostly using timestamps).  Multiple Pomodoro timers can be run by
    using different files.  Default: \$HOME/.local/share/pomo.
POMO_WORK_TIME
    Duration of the work period in minutes.  Default: 25.
POMO_BREAK_TIME
    Duration of the break period in minutes.  Default: 5.
END
}

#--- Command-line interface ---

action=
while getopts h arg; do
    case $arg in
        h|?)
            action=usage
            ;;
    esac
done
shift $(($OPTIND-1))

actions="start stop pause restart clock usage"
for act in $actions; do
    if [[ $act == $1 ]]; then
        action=$act
        break
    fi
done

if [[ -n $action ]]; then
    pomo_$action
else
    [[ $# -gt 0 ]] && echo "Unknown option/action: $1." || echo "Action not supplied."
    pomo_usage
fi

# TODO:
# + README
# + github
# + zenity/notify daemon
# + document