#!/usr/bin/env pwsh
#Requires -Version 7


#@ <Introduction>
#@ This script aims to arrange files among local path and sync paths, including onedrive and baidusync here.
#@ The operations contain: sort, 
#@ </Introduction>

param (
    # [ValidateSet("sort", "show", "restore", "pack")]
    [string]$action,
    [string]$arg1,
    [string]$arg2,
    [string]$arg3,
    [Alias("h")]
    [switch]$help,
    [Alias("eo")]
    [switch]$echo_only
)

$realself = Get-Item $PSCommandPath
if ($realself.Attributes -match "ReparsePoint") {
    $realself = Get-Item $realself.Target
}
$realDir = $realself.DirectoryName

. (Join-Path $realDir "base.ps1")

#@ Main
#@ .show_help
function show_help {
    param(
        [string]$action
    )

    # ================== show help info. based on action
    if ($action -eq "") {
        Write-Output @"
[~] Usage
    robs.ps1 <action> [target] [options]

Supported actions:
    ● sort      robs.ps1 sort -h
    ● restore   robs.ps1 restore -h
    ● pack      robs.ps1 pack -h
    ● show      robs.ps1 pack -h
    ● rename    robs.ps1 rename -h

Global options:
    ● -eo, -echo_only
        Do not do the execution, but only echo the commands
    ● -v, -verbose
        Print all detailed messages
    ● -h, -help
        Show the help information for this script
"@
    }
    elseif ($action -eq "sort") {
        Write-Output @"
robs.ps1 for action:sort, aims to sort file & directories among r.o.b.s. To be specific, based on local Roadelse/ (r.), move suitable items to OneDrive/BaiduSync and link them back, or directly link back in a new host.

[~] Usage
    robs.ps1 sort [target] [options]

[target]    any directory or file:.reconf within r.o.b.s. projects. use "." if not specified
[options]
    ● -h | -help
        Show the hepl info. for action:sort
    ● See global options in "robs.ps1 -h"
"@
    }
    elseif ($action -eq "restore") {
        Write-Output @"
robs.ps1 for action:restore, aims to gather all items from Onedrive/Baidusync, via "move" or "copy"

[~] Usage
    robs.ps1 restore [target] [options]

[target]    any directory or file:.reconf within r.o.b.s. projects. use "." if not specified
[options]
    ● -h | -help
        Show the hepl info. for action:restore
    ● -op | -restore_op, default("Move"), validateSet("Move", "Copy")
        Choose transfer operation
    ● See global options in "robs.ps1 -h"

"@
    }
    elseif ($action -eq "pack") {
        Write-Output @"
robs.ps1 for action:pack, aims to package target dir and move it to StaticRecall

[~] Usage
    robs.ps1 pack [target] [options]

[target]    any directory or file:.reconf within r.o.b.s. projects. use "." if not specified
[options]
    ● -h | -help
        Show the hepl info. for action:restore
    ● See global options in "robs.ps1 -h"

"@
    }
    elseif ($action -eq "show") {
        Write-Output @"
action:show in robs.ps1, aiming to show correspoinding robs paths with relative operations

[~] Usage
    robs.ps1 show [target] [options]

[target]    any directory or file, use "." if not specified
[options]
    ● -h | -help
        Show the hepl info. for action:restore
    ● -goto, combine(r,o,b,s,a)
        go to target path in shell, detecting the 1st valid char
    ● -open
        if set to $true, -goto will open file explorers for all valid (r,o,b,s,a) paths
    ● See global options in "robs.ps1 -h"

[~] Output
    Roadelse        (x)* : /mnt/d/recRoot/Roadelse/Acad
    OneDrive        (√)  : /mnt/c/Users/mercu/OneDrive/recRoot/Roadelse/Acad
    BaiduSync       (√)  : /mnt/d/BaiduSyncdisk/recRoot/Roadelse/Acad
    StaticRecall    (x)  : /mnt/d/recRoot/StaticRecall/Acad
    Where, √ represent existence and x doesn't; * represents PWD-robsys
"@
    }
    elseif ($action -eq "rename") {
        Write-Output @"
robs.ps1 for action:rename, aims to rename file and its symlinks simultaneously

[~] Usage
    robs.ps1 rename <target> <newname> [options]

<target>    any existed directory or file
<newname>   new name
[options]
    ● -h | -help
        Show the hepl info. for action:restore
    ● See global options in "robs.ps1 -h"

"@
    }
    else {
        Write-Error "Should Never be displayed!" -ErrorAction Stop
    }
}



function show_robs() {
    param(
        $target,
        [switch]$help,
        [string]$goto,
        [switch]$open
    )
    if ($help) {
        show_help -action show
        return
    }

    $lr = [lurric]::new($target)
    $lr.show_status($goto, $open)
}

function sort_robs() {
    param(
        $target,
        [switch]$echo_only
    )
    $lr = [lurric]::new($target)
    $lr.echo_only = $echo_only
    $lr.reloc()
}

#@ Entry
if ($action.ToLower() -eq "sort") {
    sort_robs $arg1 -echo_only:$echo_only
}
elseif ($action.ToLower() -eq "restore") {
    restore_dir @PSBoundParameters
}
elseif ($action.ToLower() -eq "pack") {
    pack2StaticRecall @PSBoundParameters
}
elseif ($action.ToLower() -eq "show") {
    show_robs $arg1 -help:$help -goto $goto -open:$open
}
elseif ($action.ToLower() -eq "rename") {
    Write-Host $PSBoundParameters
    rename @PSBoundParameters
}
else {
    show_help
}