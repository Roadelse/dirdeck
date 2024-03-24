#!/usr/bin/env pwsh
#Requires -Version 7


#@ prepare
#@ .param
param(
    [Parameter(Position = 0)]
    [string]$action,
    [Parameter(Position = 1)]
    [string]$arg1,
    [Parameter(Position = 2)]
    [string]$arg2,
    [Parameter(Position = 3)]
    [string]$arg3,
    [string]$arg4,
    [Alias("h")]
    [switch]$help,
    [switch]$shortcut
)

# $ErrorActionPreference = "Stop"


#@ .help
if ($help) {
    Write-Output @"
[~] Usage
    dk.ps1 <action> [target]

Supported actions:
    ●`e[33m s `e[0m
    ●`e[33m g `e[0m
    ●`e[33m del `e[0m
    ●`e[33m clear `e[0m
    
    ●`e[33m wln `e[0m
        create links via windows symlink or windows shortcut

Global options:
    ● -h, -help
        Show the help information for this script
"@
    return
}



#@ .check-prerequisite
if ($null -eq $env:reSG_dat) {
    Write-Error "Cannot find environemnt variable: reSG_dat" -ErrorAction Stop
}

if (Test-Path $env:reSG_dat) {
    try {
        $namedirs = Get-Content $env:reSG_dat | ConvertFrom-Json -AsHashtable
    }
    catch {
        Write-Error "Cannot read in $env:reSG_dat as a Json file"
        throw
    }
}
else {
    $namedirs = @{}
}


#@ deprecated Implement path2win & path2wsl in itself now @2024-03-22
#@ ..check-rdeeToolkit-python
# $pyv = python3 --version
# if (-not $?) {
#     Write-Error "Cannot find python3 command: $pyv" -ErrorAction Stop
# }
# $mmp = $pyv.Split(" ")[1].Split(".")
# if ([int]$mmp[0] -lt 3 -or [int]$mmp[1] -lt 9) {
#     Write-Error "Version of python must be greater than or equal with 3.9, now is ${pyv}" -ErrorAction Stop
# }
# python -m rdee > $null
# if (-not $?) {
#     Write-Error "Cannot find rdee module" -ErrorAction Stop
# }

# Write-Host $PSCommandPath
$myself = Get-Item $PSCommandPath
if ($myself.Attributes -match "ReparsePoint") {
    $myself = Get-Item $myself.Target
}
# Write-Host "myself=$myself"
$myDir = $myself.DirectoryName
# Write-Host "myDir=$myDir"

. (Join-Path $myDir "base.ps1")

# if ($IsWindows) {
#     return
# }

function s {
    param(
        [string]$name,
        [string]$path
    )

    
    if ("" -eq $name) {
        $name = "main"
    }
    if ("" -eq $path) {
        $path = "."
    }

    $target_path = (Get-Item $path).FullName
    if (-not (Test-Path $target_path)) {
        Write-Warning "The provided path doesn't exist"
    }
    # $namedirs[$name] = python -m rdee -f path2wsl $target_path
    $namedirs[$name] = path2wsl $target_path
    # Write-Output $namedirs
    ConvertTo-Json $namedirs | Set-Content $env:reSG_dat -Encoding UTF8 -Force
}

function g {
    param(
        [string]$name
    )

    if ($name -eq "") {
        $name = "main"
    }

    if ($name -eq "list") {
        Write-Host $env:reSG_dat
        $namedirs
        return
    }

    if (-not $namedirs.Contains($name)) {
        Write-Error "Cannot find key: $name in $env:reSG_dat" -ErrorAction Stop
    }
    $path = $namedirs[$name]
    if ($IsLinux) {
        Write-Host $path
        Set-Location $path
    }
    else {
        $path_win = path2win $path
        Write-Host $path_win
        Set-Location $path_win
    }
}

function delete() {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    if ($name -eq "main") {
        Write-Host "Cannot delete the key:main in reSG_dat, skip"
        return
    }
    if (-not $namedirs.Contains($name)) {
        Write-Host "Cannot find key: $name in reSG_dat, skip"
        return
    }

    $namedirs.Remove($name)
    ConvertTo-Json $namedirs | Set-Content $env:reSG_dat -Encoding UTF8 -Force
}

function clearSG() {
    if ($namedirs.Contains("main")) {
        $namedirs2 = @{main = $namedirs["main"] }
        ConvertTo-Json $namedirs2 | Set-Content $env:reSG_dat -Encoding UTF8 -Force
    }
    else {
        Remove-Item $env:reSG_dat -Force
    }
}


Function createShortcut($src, $dst, [string]$icon = "none") {
    # echo "src=$src, ddst=$ddst"

    if (-not $IsWindows) {
        Write-Error "This fuction can only be used in Windows" -ErrorAction Stop
    }

    $WScriptShell = New-Object -ComObject WScript.Shell
    
    if (Test-Path -Path $dst -PathType Container) {
        $dst = $dst + "\" + [System.IO.Path]::GetFileName($src) + ".lnk"
    }

    if (-not $dst.Endswith(".lnk")) {
        $dst = $dst + ".lnk"
    }
    # Write-Host "(createShortcut) src=$src"
    # Write-Host "(createShortcut) dst=$dst"

    $Shortcut = $WScriptShell.CreateShortcut($dst)
    $Shortcut.TargetPath = $src
    if ($icon -ne "none") {
        $shortcut.IconLocation = $icon
    }
    #Save the Shortcut to the TargetPath
    $Shortcut.Save()
}


function wln() {
    param(
        [Parameter(Mandatory = $true)]
        [string]$src,
        [string]$dst,
        [switch]$shortcut
    )

    if (-not $dst) {
        $dst = $PWD
    }

    # Write-Host $PWD.Path

    $src_wr = [wurin]::new($src)
    $dst_wr = [wurin]::new($dst)

    if ($IsWSL) {
        # Write-Host "Calling windows!"
        # Write-Host "dk.ps1 wln $($src_wr.uri_win) $($dst_wr.uri_win) -shortcut:`$$shortcut"
        pwsh.exe -c "dk.ps1 wln $($src_wr.uri_win) $($dst_wr.uri_win) -shortcut:`$$shortcut"
        return
    }
    elseif ($IsWindows) {
        if ($shortcut) {
            createShortcut $src_wr.uri_win $dst_wr.uri_win
        }
        else {
            if (Test-Path $dst_wr.uri_win -PathType Container) {
                $dst_path = $dst_wr.uri_win + "\" + $src_wr.basename()
            }
            else {
                $dst_path = $dst_wr.uri_win
            }
            # Write-Host "src=$($src_wr.uri_win)"
            # Write-Host "dst=$($dst_path)"
            New-Item -ItemType SymbolicLink -Path $dst_Path -Target $src_wr.uri_win -Force > $null
        }
    }

}

function cdf() {
    param(
        [string]$uri
    )
    # To-Be-Done
}

#@ mains
switch ($action) {
    "s" {
        s $arg1 $arg2
    }
    "g" {
        g $arg1
    }
    "del" {
        delete $arg1
    }
    "clear" {
        clearSG
    }
    "wln" {
        wln $arg1 $arg2 -shortcut:$shortcut
    }
    default {
        Write-Error "Error! Unknown action: $action" -ErrorAction Stop
    }
}