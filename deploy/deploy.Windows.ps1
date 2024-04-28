#Requires -Version 7


#@ prepare
#@ .key-ctrl-variables

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


@"
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> dirdeck
. $myDir\..\source\setenv.Windows.ps1

"@ | Set-Content .temp

python $myDir/tools/fileop.ra-block.py $profile.CurrentUserAllHosts .temp
Remove-Item .temp -Force
