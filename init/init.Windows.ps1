#!/usr/bin/env pwsh
#Requires -Version 7


#@ prepare
#@ .key-ctrl-variables
$rdeeBin = "D:\XAPP\rdee\bin"


#@ .dependent
$myDir = $PSScriptRoot

#@ .pre-check
if ($IsLinux) {
    Write-Error "This init script can only be used in Windows, please use init.Linux.sh, either" -ErrorAction Stop
}
python --version > $null
if (-not $?) {
    Write-Error "Cannot find python command" -ErrorAction Stop
}


#@ main
[Environment]::SetEnvironmentVariable("reSG_dat", "$myDir/.reSG_dat", [EnvironmentVariableTarget]::User)
Write-Host "Set environment variable: reSG_dat"

$env_path_user = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
if (-not $env_path_user.Contains($rdeeBin)) {
    [Environment]::SetEnvironmentVariable('Path', ("$env_path_user" + ";$rdeeBin"), [EnvironmentVariableTarget]::User)
    Write-Host "Append environment variable: PATH"
}
else {
    Write-Host "Skip appending env:PATH, due to existence"
}
New-Item -ItemType SymbolicLink -Path "$rdeeBin\dk.ps1" -Target "$myDir\..\dk.ps1" -Force

@"
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> dirdeck
. $myDir\supp.Windows.ps1

"@ | Set-Content .temp

python $myDir/txtop.ra-nlines.py $profile.CurrentUserAllHosts .temp ""
Remove-Item .temp -Force