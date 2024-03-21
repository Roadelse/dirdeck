#!/usr/bin/env pwsh
#Requires -Version 7

#@ prepare

param(
    [Parameter(Position = 0)]
    [string]$action,
    [Parameter(Position = 1)]
    [string]$arg1,
    [Parameter(Position = 2)]
    [string]$arg2,
    [Parameter(Position = 3)]
    [string]$arg3,
    [string]$arg4
)

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

#@ ..check-rdeeToolkit-python
$pyv = python --version
if (-not $?) {
    Write-Error "Cannot find python command: $pyv" -ErrorAction Stop
}
$mmp = $pyv.Split(" ")[1].Split(".")
if ([int]$mmp[0] -lt 3 -or [int]$mmp[1] -lt 9) {
    Write-Error "Version of python must be greater than or equal with 3.9, now is ${pyv}" -ErrorAction Stop
}
python -m rdee > $null
if (-not $?) {
    Write-Error "Cannot find rdee module" -ErrorAction Stop
}


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
    $namedirs[$name] = python -m rdee -f path2wsl $target_path
    Write-Output $namedirs
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
        Write-Error "Cannot find key: $name in $reSG_dat" -ErrorAction Stop
    }
    $path = $namedirs[$name]
    if ($IsLinux) {
        Write-Host $path
    }
    else {
        $path_win = python -m rdee -f path2win $path
        Set-Location $path_win
    }
}


#@ mains
switch ($action) {
    "s" {
        s $arg1 $arg2
    }
    "g" {
        g $arg1
    }
    default {
        Write-Error "Error! Unknown action: $action" -ErrorAction Stop
    }
}