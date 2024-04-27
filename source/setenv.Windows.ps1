

$env:reSG_dat = "$PSScriptRoot/../deploy/.reSG_dat"
$env:PATH = "$PSScriptRoot/../bin;" + $env:PATH


function s() {
    param(
        [string]$name,
        [string]$path
    )

    dms.ps1 s $name $path
}

function g() {
    param(
        [string]$name
    )

    dms.ps1 g $name
}


