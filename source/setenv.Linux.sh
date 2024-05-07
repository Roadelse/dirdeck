#!/bin/bash

#@ unload | unload the function definitions
if [[ "$1" == "unload" ]]; then
    unset -f s g dms
    unset __dmspy reSG_dat
    return
fi

#@ load
#@ .prepare
script_realpath=$(realpath "${BASH_SOURCE[0]}")
script_dir=$(dirname $script_realpath)
export __dmspy=$(realpath $script_dir/../bin/dms.py)
export reSG_dat=$script_dir/../deploy/.reSG_dat

#@ .dms | wrapper & executer for dms.py
function dms() {
    if [[ $1 == "g" && $2 == "list" ]]; then
        $__dmspy $*
        return
    fi
    rst=$($__dmspy $*)
    echo $rst
    if [[ $? -ne 0 ]]; then
        return
    fi
    if [[ $1 =~ ^'g ' || $1 == g ]]; then
        cd $rst
    fi
}

function s() {
    dms s $*
}

function g() {
    dms g $*
}

#@ .others
function cd.() {
    if [[ -z $1 ]]; then
        echo -e "\033[33m<function:cd.> requires one argument\033[0m"
        return
    fi

    if [[ ! -e $1 ]]; then
        echo -e "\033[33m<function:cd.> requires existed uri\033[0m"
    fi

    if [[ -f $1 ]]; then
        cd $(dirname $1)
    else
        cd $1
    fi
}

function cdr() {
    if [[ -z $1 ]]; then
        echo -e "\033[33m<function:cdr> requires one argument\033[0m"
        return
    fi
    rpath=$(realpath $1)
    if [[ ! -e $rpath ]]; then
        echo -e "\033[33m<function:cdr> requires existed uri\033[0m"
    fi

    cd. $rpath
}

function cd0() {
    cdr .
}
