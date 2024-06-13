#!/bin/bash

if [[ "$1" == "unload" ]]; then
    unset -f dms s g rob
    unset __dmspy reSG_dat __robsps1
    return
fi

script_realpath=$(realpath "${BASH_SOURCE[0]}")
script_dir=$(dirname $script_realpath)
export __dmsps1=$(realpath $script_dir/../bin/dms.ps1)
export __robsps1=$(realpath $script_dir/../bin/robs.ps1)
export reSG_dat=$script_dir/../deploy/.reSG_dat

#@ .dms | wrapper & executer for dms.py
function dms() {
    if [[ $1 == "g" && $2 == "list" ]]; then
        $__dmsps1 $*
        return
    fi
    rst=$($__dmsps1 $*)
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

function rob() {
    $__robsps1 ${*:1} |& tee .robTemp
    if [[ $? -eq 0 ]]; then
        lastLine=$(tail -n 1 .robTemp)
        if [[ "$lastLine" =~ ^cd ]]; then
            $lastLine
        fi
    fi
    rm -f .robTemp
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


function cdRepo() {
    local tardir=${PWD}
    while [[ 1 ]]; do
        if [[ $tardir == / ]]; then
            return
        fi
        if [[ -e $tardir/.git ]]; then
            cd $tardir
            return
        fi
        tardir=$(dirname $tardir)
    done
}
