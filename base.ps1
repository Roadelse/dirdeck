#!/usr/bin/env pwsh
#Requires -Version 7

$IsWSL = $false

if ($IsLinux -and $env:WSL_DISTRO_NAME) {
    $IsWSL = $true
}


class wurin {
    [string]$uri_linux
    [string]$uri_win

    wurin([string]$s) {
        #@ branch for abstract path
        if ($s.StartsWith("/")) {
            $this.uri_linux = $s
            $this.uri_win = path2win $s
        }
        elseif ($s -match "[A-Z]:\\") {
            $this.uri_win = $s
            $this.uri_linux = path2wsl $s
        }
        else {
            if ($global:IsLinux) {
                $this.uri_linux = Join-Path $PWD.Path $s
                $this.uri_win = path2win $this.uri_Linux
            }
            else {
                $this.uri_win = Join-Path $PWD.Path $s
                $this.uri_linux = path2wsl $this.uri_win
            }
        }
    }

    [bool]existed() {
        if ($global:IsLinux) {
            return [bool](Test-Path $this.uri_linux)
        }
        else {
            return [bool](Test-Path $this.uri_win)
        }
    }

    [string]basename() {
        return [System.IO.Path]::GetFileName($this.uri_linux)
    }
}


function path2win() {
    param(
        [Parameter(Mandatory = $true)]
        [string]$path_wsl,
        [switch]$strict
    )
    if ($path_wsl -match "[A-Z]:\\") {
        #@ branch already be a windows path
        return $path_wsl
    }
    if (-not $path_wsl.StartsWith("/mnt/")) {
        #@ branch not a win-in-wsl path
        if ($strict) {
            Write-Error "Cannot convert a pure linux path into windows path! $path_wsl" -ErrorAction Stop
        }
        else {
            return ""
        }
    }

    $path_win = $path_wsl.Substring(5, 1).ToUpper() + ":\"
    if ($path_wsl.Length -ge 7) {
        $path_win = $path_win + $path_wsl.Substring(7, $path_wsl.Length - 7).Replace("/", "\") 
    }
    return $path_win
}

function path2wsl() {
    param(
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [string]$path_win,
        [switch]$strict
    )
    if ($path_win.StartsWith("/")) {
        #@ branch already be a wsl path
        return $path_win
    }
    if (-not ($path_win -match "[A-Z]:\\")) {
        if ($strict) {
            Write-Error "Not a windows path! $path_win" -ErrorAction Stop
        }
        else {
            return ""
        }
    }
    $path_wsl = "/mnt/" + $path_win.Substring(0, 1).ToLower() + "/" + $path_win.Substring(3, $path_win.Length - 3).Replace("\", "/")
    return $path_wsl
}