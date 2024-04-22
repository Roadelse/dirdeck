#!/usr/bin/env pwsh
#Requires -Version 7


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
