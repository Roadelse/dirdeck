#!/bin/bash

###########################################################
# This scripts aims to initialize the running environment #
# for repository <reSync>, including:                     #
#    ● gather correponding binary to target dir           #
#    ● generate init script                               #
#    ● generate modulefile                                #
# --------------------------------------------------------#
# by Roadelse                                             #
#                                                          #
# 2024-03-21    created                                   #
###########################################################

#@ <prepare>
#@ <.depVars>  dependent variables
myDir=$(cd $(dirname "${BASH_SOURCE[0]}") && readlink -f .)
curDir=$PWD

#@ <.pre-check>
#@ <..python>
if [[ -z $(which python3 2>/dev/null) ]]; then
    echo '\033[31m'"Error! Cannot find python interpreter"'\033[0m'
    exit 200
fi
#@ ...py-version
pyv=$(python3 --version | cut -d' ' -f2)
if [[ $(echo $pyv | cut -d. -f1) -lt 3 || $(echo $pyv | cut -d. -f2) -lt 6 ]]; then
    echo '\033[31m'"Error! python version must be greater than or equal with 3.6"'\033[0m'
    exit 200
fi
#@ <..powershell>
if [[ -z $(which pwsh 2>/dev/null) ]]; then
    echo '\033[31m'"Error! Cannot find pwsh shell"'\033[0m'
    exit 200
fi

#@ <.arguments>
#@ <..default>
binary_dir=${PWD}/bin
setenvfile=${PWD}/load.dirdeck.sh
modulefile=${PWD}/dirdeck
profile=
#@ <..resolve>
while getopts "b:s:m:p:" arg; do
    case $arg in
    b)
        binary_dir=$OPTARG
        ;;
    s)
        setenvfile=$OPTARG
        ;;
    m)
        modulefile=$OPTARG
        ;;
    p)
        profile=$OPTARG
        ;;
    esac
done

#@ <.header> create header for setenv and module files
cat <<EOF >$setenvfile
#!/bin/bash

EOF

cat <<EOF >$modulefile
#%Module 1.0

EOF

#@ <core>
# <.binary> organize executable
# <..dk>
mkdir -p $binary_dir && cd $_
ln -sf $(realpath $myDir/../bin/dk.py) .

# <.setenv>
cat <<EOF >$setenvfile
#!/bin/bash

export PATH=${binary_dir}:\$PATH
export reSG_dat=$myDir/.reSG_dat
. $myDir/../source/setenv.Linux.sh

EOF

cat <<EOF >$modulefile
#%Module 1.0

prepend-path PATH ${binary_dir}
setenv reSG_dat $myDir/.reSG_dat
if { [module-info mode load] } { puts "source $myDir/../source/setenv.Linux.sh" }
if { [module-info mode remove] } { puts "source $myDir/../source/setenv.Linux.sh unload" }

EOF

#@ <post> modify profile
cd $curDir
set -e
if [[ -n $profile ]]; then
    read -p "profile detected, which way to init rdeeToolkit? [setenv|module] default:module " sm
    if [[ -z $sm ]]; then
        sm=module
    fi

    # echo "sm=$sm"

    if [[ $sm == "module" ]]; then
        moduledir=$(dirname $modulefile)
        cat <<EOF >>.temp
# >>>>>>>>>>>>>>>>>>>>>>>>>>> [dirdeck]
module use $moduledir
module load dirdeck

EOF
        python $myDir/txtop.ra-nlines.py $profile .temp
        rm -f .temp
    elif [[ $sm == "setenv" ]]; then
        cat <<EOF >>.temp
# >>>>>>>>>>>>>>>>>>>>>>>>>>> [dirdeck]
source $setenvfile

EOF
        python $myDir/txtop.ra-nlines.py $profile .temp
        rm -f .temp
    else
        echo "Unknown input: $sm"
        exit 200
    fi
fi
