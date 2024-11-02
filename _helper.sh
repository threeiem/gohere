#!/usr/bin/env bash

# Initialize colors with defaults in case they're not set
Reset=""
Bold=""
Black=""
White=""
Red=""
Green=""
Yellow=""
Blue=""
Purple=""
Cyan=""

# Colors/Views
Reset=$({ tput sgr0 || tput me;} 2> /dev/null)

[[ -t 1 ]] && [[ -n "$TERM" ]] && [[ ! "$TERM" =~ .*-m ]] && [[ "$TERM" != "dumb" ]] && {
    Bold=$({ tput bold || tput md;} 2> /dev/null)
    Black=$({ tput setaf 0 || tput AF 0;} 2> /dev/null)
    White=$({ tput setaf 7 || tput AF 7;} 2> /dev/null)
    Red=$({ tput setaf 1 || tput AF 1;} 2> /dev/null)
    Green=$({ tput setaf 2 || tput AF 2;} 2> /dev/null)
    Yellow=$({ tput setaf 3 || tput AF 3;} 2> /dev/null)
    Blue=$({ tput setaf 4 || tput AF 4;} 2> /dev/null)
    Purple=$({ tput setaf 5 || tput AF 5;} 2> /dev/null)
    Cyan=$({ tput setaf 6 || tput AF 6;} 2> /dev/null)
}

# Initialize login to github. (2fa stuff)
init_keys(){
    ssh -T git@github.com 2>&1 | awk -F, '{print $1}' || true
}

# message [title] [body] - Print a message title and body
message(){
    local title="${1:-INFO}"
    shift || true
    local body="${*:-¯\_(ツ)_/¯}"
    printf '%s [%s%s%s] %s%s%s\n' "$(TZ='UTC' date -Isec)" "${Bold:-}${White:-}" "${title}" "${Reset:-}" "${Bold:-}" "${body}" "${Reset:-}"
}

# info [message] - Print a informational message
info(){
    local body="${1:-Sometime interesting happened. ¯\_(ツ)_/¯}"
    message "${Green:-}INFO${Reset:-}" "${body}"
}

# warn [message] - Print a warning message
warn(){
    local body="${1:-Something is weird. ¯\_(ツ)_/¯}"
    message "${Yellow:-}WARN${Reset:-}" "${body}" >&2
}

# error [message] - Print error message
error(){
    local body="${1:-We messed up. ¯\_(ツ)_/¯}"
    message "${Red:-}ERROR${Reset:-}" "${White:-}${body}${Reset:-}" >&2
}

# Generate a timestamp with an adjustable time signature. (ISO only in logging)
get_utc() {
    local signature="${1:-%Y%m%dT%H%M}"
    TZ='UTC' date +"${signature}"
}

# Get a unique identifier with an adjustable length (/dev/urandom)
get_uid(){
    local length="${1:-6}" # Default to 6 if no argument is provided
    od -An -N$((length/2)) -t x1 /dev/urandom | tr -d ' ' | head -c "${length}"
}

# Strip both ANSI color codes and tput-based formatting
strip_color(){
    sed -E '
        s/\x1b\[[0-9;]*[mGKHF]//g
        s/\x1b\[([0-9]{1,2}(;[0-9]{1,2})*)?[mGKHF]//g
        s/\x1b\[([0-9]{1,2}(;[0-9]{1,2})*)?[A-Za-z]//g
        s/\x1b\[(B|C|D|E|F|G|H|I|J|K|L|M|S|T)//g
        s/\x1b\[[0-9;]*[A-Za-z]//g
        s/\x1b[PX^_].*\(\x1b\\|$\)//g
        s/\x1b\[?[0-9;]*[A-Za-z]//g
        s/\x1b\(B//g
        s/\x0e//g
        s/\x0f//g
    ' | tr -d '\r'
}
