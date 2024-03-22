#!/bin/bash

if [[ "$1" == "unload" ]]; then
    unset -f s
    unset -f g
    return
fi

function s() {
    if [[ -z "$1" ]]; then
        name=main
    fi
    # if [[ -z "$2" ]]; then
    #     path=${PWD}
    # fi
    dk s $name $path
}

function g() {
    if [[ "$1" == "list" ]]; then
        echo "$(dk g list)"
    else
        cd "$(dk g $1)"
    fi
}