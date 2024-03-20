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
    [string]$arg3
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

function s {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name,
        [string]$path
    )

    if ($null -eq $path) {
        $path = "."
    }

    $target_path = (Get-Item $path).FullName
    if (-not (Test-Path $target_path)) {
        Write-Warning "The provided path doesn't exist"
    }
    $namedirs[$name] = $target_path
    ConvertTo-Json $namedirs | Set-Content $env:reSG_dat -Encoding UTF8 -Force
}

function g {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    if (-not $namedirs.Contains($name)) {
        Write-Error "Cannot find key: $name in $reSG_dat" -ErrorAction Stop
    }
    Write-Host $namedirs[$name]
    Set-Location $namedirs[$name]
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