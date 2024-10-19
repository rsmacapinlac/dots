#!/bin/sh

run() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
}

~/.config/polybar/launch.sh
run "compton"
