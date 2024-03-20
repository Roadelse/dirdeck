#!/usr/bin/env pwsh
#Requires -Version 7


$myDir = $PSScriptRoot


if ($IsLinux) {
    Write-Error "To be developed" -ErrorAction Stop
}
elseif ($IsWindows) {
    [Environment]::SetEnvironmentVariable("reSG_dat", "$myDir/.reSG_dat", [EnvironmentVariableTarget]::User)
    Write-Host "Set environment variable: reSG_dat"

    $rdeeBin = "D:\XAPP\rdee\bin"
    $env_path_user = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
    if (-not $env_path_user.Contains($rdeeBin)) {
        [Environment]::SetEnvironmentVariable('Path', ("$env_path_user" + ";$rdeeBin"), [EnvironmentVariableTarget]::User)
        Write-Host "Append environment variable: PATH"
    }
    else {
        Write-Host "Skip appending env:PATH, due to existence"
    }
    New-Item -ItemType SymbolicLink -Path "$rdeeBin\dk.ps1" -Target "$myDir\dk.ps1"
}
else {
    Write-Error "Unsupported operation system, nor Linux neither Windows" -ErrorAction Stop
}