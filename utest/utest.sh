#!/usr/bin/env bats

setup_file() {
    export PATH=$BATS_TEST_DIRNAME/../bin:$PATH
    export utestdir=$BATS_TEST_DIRNAME/ade.utest
    # echo $BATS_TEST_DIRNAME/../init/supp.Linux.sh > tmp
    mkdir -p $utestdir
}

teardown_file() {
    rm -rf $utestdir
}

@test "dms" {
    . $BATS_TEST_DIRNAME/../source/setenv.Linux.sh
    cd $utestdir
    s
    cd 
    g
    [[ $PWD == $utestdir ]]
}

@test "change-directory" {
    . $BATS_TEST_DIRNAME/../source/setenv.Linux.sh
    mkdir -p $utestdir/change-directory
    cd $utestdir/change-directory
    mkdir d1
    ln -s d1 d2
    touch d1/f1
    cd. d1/f1
    [[ $PWD == "$utestdir/change-directory/d1" ]]
    cd ../d2
    cd0
    [[ $PWD == "$utestdir/change-directory/d1" ]]
    cd ../d2
    cdr f1
    [[ $PWD == "$utestdir/change-directory/d1" ]]
}