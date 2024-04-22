#!/usr/bin/env pwsh
#Requires -Version 7

#@ <Introduction>
#@ This script aims to arrange files among local path and sync paths, including onedrive and baidusync here.
#@ The operations contain: sort, 
#@ </Introduction>


#@ Prepare
#@ .arguments
param (
    # [ValidateSet("sort", "show", "restore", "pack")]
    [string]$action,
    [string]$arg1,
    [string]$arg2,
    [string]$arg3,
    [Alias("h")]
    [switch]$help,
    [Alias("eo")]
    [switch]$echo_only,
    [switch]$error_stop,
    [Alias("v")]
    [switch]$verbose,
    # ... for action:restore
    [string]$restore_op,
    # ... for action:show
    [string]$goto,
    [switch]$open
)

#@ .pre-load
Import-Module rdee
$myself = Get-Item $PSCommandPath
if ($myself.Attributes -match "ReparsePoint") {
    $myself = Get-Item $myself.Target
}
$myDir = $myself.DirectoryName
. (Join-Path $myDir "base.ps1")

# $rrR = [wurin]::new("D:\recRoot\Roadelse")
# $rrO = [wurin]::new("C:\Users\mercu\OneDrive\recRoot\Roadelse")
# $rrB = [wurin]::new("D:\BaiduSyncdisk\recRoot\Roadelse")
# $rrS = [wurin]::new("D:\recRoot\StaticRecall")





exit 0


#@ .key-ctrl-params
#@ ..r.o.b.s. root paths
$rrR = [wurin]::new("D:\recRoot\Roadelse")
$rrO = [wurin]::new("C:\Users\mercu\OneDrive\recRoot\Roadelse")
$rrB = [wurin]::new("D:\BaiduSyncdisk\recRoot\Roadelse")
$rrS = [wurin]::new("D:\recRoot\StaticRecall")

#@ .golbal-variables
$ignore_global = @(".reconf$", ".resync_config$", "resort-error\..*\.log$", "^prior\.", "^deprecated\.", ".obsidian")
[System.Collections.ArrayList]$sorted_dirs = @()


#@ .check
if ($IsLinux -and -not $IsWSL) {
    Write-Error "This script only work in Windows or WSL!" -ErrorAction Stop
}

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

function norm_path {
    #@ Introduction | return all r./o./b./s. paths given any of them
    [OutputType([wurin[]])]
    param(
        $target
    )


    # ================== set $pwd as default target if not specified
    if ($null -eq $target -or "" -eq $target) {
        $target = [wurin]::new(".")
    }

    if ($target -is [string]) {
        $target = [wurin]::new($target)
    }


    # ================== get target directory path
    # $target = [IO.Path]::GetFullPath($target, $pwd.ProviderPath)
    # Write-Host "target=$($target.uri_auto())"
    # Write-Host "rrO=$($rrO.uri_auto())"

    if ($target.StartsWith($rrO)) {
        $rpath = $target.Replace($rrO, $rrR)
        $opath = $target
        $bpath = $target.Replace($rrO, $rrB)
        $spath = $target.Replace($rrO, $rrS)
    }
    elseif ($target.StartsWith($rrB)) {
        $rpath = $target.Replace($rrB, $rrR)
        $opath = $target.Replace($rrB, $rrO)
        $bpath = $target
        $spath = $target.Replace($rrB, $rrS)
    }
    elseif ($target.StartsWith($rrS)) {
        $rpath = $target.Replace($rrS, $rrR)
        $opath = $target.Replace($rrS, $rrO)
        $bpath = $target.Replace($rrS, $rrB)
        $spath = $target
    }
    elseif ($target.StartsWith($rrR)) {
        $rpath = $target
        $opath = $target.Replace($rrR, $rrO)
        # Write-Host $rrR.uri_auto(), $rrO.uri_auto()
        # Write-Host $opath.uri_auto()

        $bpath = $target.Replace($rrR, $rrB)
        $spath = $target.Replace($rrR, $rrS)
    }
    else {
        #>- Error if not within r.o.b.s. system
        Write-Error "Path not in r.o.b.s. system! $($target.uri_auto())" -ErrorAction Stop
    }

    
    # Write-Host "rpath=$($rpath.uri_auto())"
    # Write-Host "opath=$($opath.uri_auto())"
    # Write-Host "bpath=$($bpath.uri_auto())"
    # Write-Host "spath=$($spath.uri_auto())"
    # exit 0

    return $rpath, $opath, $bpath, $spath
}

#@ .show_robs
function show_robs {
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
    $rpath, $opath, $bpath, $spath = norm_path $target


    # ================== render √ and × char with ANSI color code
    function checkE {
        param(
            [wurin]$p
        )
        if ($p.existed()) {
            return "`e[32m√`e[0m"
        }
        else {
            return "`e[31m×`e[0m"
        }
    }
    function existSymbol([wurin]$p) {
        if ($p.StartsWith($pwd.ProviderPath)) {
            return "*"
        }
        else {
            return " "
        }
    }

    # $es_r = existSymbol $rpath
    # $es_r = existSymbol $rpath
    # $es_o = existSymbol $opath
    # $es_b = existSymbol $bpath
    # $es_s = existSymbol $spath
    # exit 0
    # ================== print paths
    Write-Host @"
Roadelse    `t($(checkE $rpath))$(existSymbol $rpath) : $($rpath.uri_auto())
OneDrive    `t($(checkE $opath))$(existSymbol $opath) : $($opath.uri_auto())
BaiduSync   `t($(checkE $bpath))$(existSymbol $bpath) : $($bpath.uri_auto())
StaticRecall`t($(checkE $spath))$(existSymbol $spath) : $($spath.uri_auto())
"@

    # ================== handle $goto param
    if ($goto) {
        [System.Collections.ArrayList]$dirs2go = @()
        if ($goto -match "a") {
            $dirs2go = $rpath, $opath, $bpath, $spath
        }
        else {
            if ($goto -match "r") {
                $dirs2go.Add($rpath) > $null
            }
            if ($goto -match "o") {
                $dirs2go.Add($opath) > $null
            }
            if ($goto -match "b") {
                $dirs2go.Add($bpath) > $null
            }
            if ($goto -match "s") {
                $dirs2go.Add($spath) > $null
            }
        }
        # Write-Output $dirs2go

        if ($goto.Count -eq 0) {
            Write-Error "Error! param:`$goto doesn't contain any of r, o, b, s, a" -ErrorAction Stop
        }
        
        # ~~~~~~~~~~ if $open, open the file explorer
        if ($open) {
            $dirs2go | ForEach-Object {
                if ($IsWindows) {
                    Invoke-Item $_.uri_win 
                }
                else {
                    pwsh.exe -c "Invoke-Item $($_.uri_win)"
                }
            } 
        }
        else {
            if (-not $IsSubShell) {
                Set-Location $dirs2go[0].uri_auto()
            }
            else {
                Write-Host "cd $($dirs2go[0].uri_auto())"
            }
        }
    }
}





# >>>>>>>>>>> sort content in target directory <<<<<<<<<<<<
function sort_dir {
    <# .SYNOPSIS
    This function aims to sort all files/directories in the target directory. That is, move files/dirs into OneDrive and BaiduSync paths and link them back based on several rules. 
    
    .PARAMETER wdir
    target working directory
    #>

    # ================== parameters definition
    param(
        $target,
        $rcf = @{},
        [Alias("h")]
        [switch]$help
    )

    if ($help) {
        show_help -action sort
        return
    }

    # ================== pre-processing
    # ~~~~~~~~~~ handle r.o.b. paths 
    $rpath, $opath, $bpath, $spath = norm_path $target

    # ~~~~~~~~~~ load .reconf if existed
    if (Test-Path "${rpath}\.reconf") {
        if (-not ((Get-Item "${rpath}\.reconf").Attributes -match "ReparsePoint")) {
            #>- added @2024-01-11
            move_and_link (Get-Item "${rpath}\.reconf") $opath\.reconf
        }
        Update-Hashtable $rcf (Get-Content "${rpath}\.reconf" | ConvertFrom-Json -AsHashtable)
    }
    elseif (Test-Path "${opath}\.reconf") {
        Update-Hashtable $rcf (Get-Content "${opath}\.reconf" | ConvertFrom-Json -AsHashtable)
    }
    
    # ~~~~~~~~~~ check ignore_this and 
    if ($rcf.ignore_this) {
        return
    }

    # ~~~~~~~~~~ remark current target in global
    $sorted_dirs.Add($rpath.Replace($rrR + "\", "")) | Out-Null

    # ================== handle children items one by one
    Get-ChildItem $rpath | 
    ForEach-Object -Process {
        # ~~~~~~~~~~ ignore symlink
        if ($_.Attributes -match "ReparsePoint") {
            return
        }

        # Write-Output "processing $_"
        # ~~~~~~~~~~ check ignore_global
        foreach ($ig in $ignore_global) {
            if ($_.Name -match $ig) {
                return
            }
        }

        # ~~~~~~~~~~ check ignore list in rcf
        if ($rcf.Contains('ignore_list') -and $rcf.ignore_list.Contains($_.Name)) {
            #>- manual ignore
            return
        }

        # ~~~~~~~~~~ Do the operation via manually set rule
        if ($rcf.Contains('OneDrive') -and $rcf.OneDrive.Contains($_.Name)) {
            move_and_link $_ (r2o $_.FullName)
            return
        }
        elseif ($rcf.Contains('Baidusync') -and $rcf.Baidusync.Contains($_.Name)) {
            move_and_link $_ (r2b $_.FullName)
            return
        }

        # ~~~~~~~~~~ Do the operation via name prefix rule
        if ($_.Name.StartsWith("O..")) {
            Write-Output "`e[33mRename`e[0m $($_.Name), following move_and_link would use original name"
            $newName = $_.Name.Replace("O..", "")
            $newPath = (Split-Path $_) + "\$newName"
            $ftemp = $_
            # Write-Output newPath=$newPath
            if (-not $echo_only) {
                Rename-Item $_.FullName -NewName $newName
                $ftemp = Get-Item $newPath
            }
            move_and_link $ftemp (r2o $newPath)
            return
        }
        elseif ($_.Name.StartsWith("B..")) {
            Write-Output "`e[33mRename`e[0m $($_.Name), following move_and_link would use original name"
            $newName = $_.Name.Replace("B..", "")
            $newPath = $_.DirectoryName + "/$newName"
            $ftemp = $_
            if (-not $echo_only) {
                Rename-Item $_.FullName -NewName $newName
                $ftemp = Get-Item $newPath
            }
            move_and_link $ftemp (r2b $newPath)
            return
        }

        # ~~~~~~~~~~ handle children dir recursively
        if ($_.PSIsContainer) {
            sort_dir -target $_ -rcf (deepcopy $rcf)

            # ~~~~~~~~~~ Do the operation in default rules
        }
        else {
            $fsize = $_.Length / 1MB; # file size in MB
            if ($fsize -lt 5) {
                move_and_link $_ $_.FullName.Replace($rrR, $rrO)
            }
            elseif ($fsize -lt 200) {
                move_and_link $_ $_.FullName.Replace($rrR, $rrB)
            }
        }
        # exit 0
    }

    # ================== link back items in OneDrive
    if (Test-Path $opath) {
        Get-ChildItem $opath | ForEach-Object -Process {
            $_lp = o2r $_.FullName  #>- corresponding local path for $_.FullName
            if (Test-Path $_lp) {
                # ~~~~~~~~~~ handle shortcut links separately (should only in onedrive!)
                if ($_lp.EndsWith(".lnk") -and (-not (Test-Path $_lp))) {
                    Write-Host "`e[33mCopy-Item shortcut`e[0m from OneDrive to local Roadelse: $($_.Name)"
                    if (-not $echo_only) {
                        Copy-Item -Path $_.FullName -Destination $_lp
                    }
                    continue
                }

                # ~~~~~~~~~~ handle error conditions
                $i_lp = Get-Item $_lp
                if (-not ($i_lp.Attributes -match "ReparsePoint")) {
                    if ($i_lp.PSIsContainer) {
                        if (-not $sorted_dirs.Contains($_lp.Replace($rrR + "\", ""))) {
                            errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                        }
                    }
                    else {
                        errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                    }
                }
            }
            else {
                # ~~~~~~~~~~ do the link operation
                Write-Host ("`e[33mlink`e[0m OneDrive item: " + $_lp.Replace($rrR + "\", "") + " to Local")
                if (-not $echo_only) {
                    New-Item -ItemType SymbolicLink -Path $_lp -Target $_.FullName
                }
            }
        }
    }

    # ================== link back items in BaiduSync
    if (Test-Path $bpath) {
        Get-ChildItem $bpath | ForEach-Object -Process {
            Assert (-not $_.FullName.EndsWith(".lnk")) "Shortcut links should not occur in BaiduSync!" #>- ensure no shortcut link
            $_lp = b2r $_.FullName  #>- corresponding local path for $_.FullName
            if (Test-Path $_lp) {
                # ~~~~~~~~~~ handle error conditions
                $i_lp = Get-Item $_lp
                if (-not ($i_lp.Attributes -match "ReparsePoint")) {
                    if ($i_lp.PSIsContainer) {
                        if (-not $sorted_dirs.Contains($_lp.Replace($rrR + "\", ""))) {
                            errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                        }
                    }
                    else {
                        errHandler ("File conflict: " + $_lp.Replace($rrR + "\", ""))
                    }
                }
            }
            else {
                # ~~~~~~~~~~ do the link operation
                Write-Host ("`e[33mlink`e[0m BaiduSync item: " + $_lp.Replace($rrR + "\", "") + " to Local")
                if (-not $echo_only) {
                    New-Item -ItemType SymbolicLink -Path $_lp -Target $_.FullName
                }
            }
        }
    }
}


#@ Auxiliary
function errHandler {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$errmsg
    )
    Write-Error "Error: $errmsg" -ErrorAction ($error_stop ? "Stop" : "continue")
}

function r2o {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )
    return $ldir.Replace($rrR, $rrO)
}

function o2r {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    ) 

    return $ldir.Replace($rrO, $rrR)
}

function r2b {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    return $ldir.Replace($rrR, $rrB)
}

function b2r {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ldir
    )

    return $ldir.Replace($rrB, $rrR)
}





#@ Entry
if ($action.ToLower() -eq "sort") {
    sort_dir @PSBoundParameters
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