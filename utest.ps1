#Requires -Version 7


Describe "dirdeck unit tests" {

    BeforeAll {
        . .\base.ps1
        New-Item -ItemType Directory dk_utest -Force
        Set-Location dk_utest
        if ($IsLinux) {
            $env:PATH = $PSScriptRoot + ":" + $env:PATH
        }
        else {
            $env:PATH = $PSScriptRoot + ";" + $env:PATH
        }
        $env:reSG_dat = Join-Path $PWD.Path "reSG_dat"
    }

    It "s/g/del/clear" -Tag "sg" {
        Set-Location $PSScriptRoot/dk_utest
        New-Item -ItemType Directory a\b\c -Force
        dk.ps1 s
        Set-Location a\b\c
        dk.ps1 s dc
        dk.ps1 g
        $PWD.Path | Should -Be (Join-Path $PSScriptRoot "dk_utest")
        dk.ps1 g dc
        $PWD.Path | Should -Be (Join-Path $PSScriptRoot "dk_utest/a/b/c")
        dk.ps1 g
        dk.ps1 del dc
        $namedirs = Get-Content $env:reSG_dat | ConvertFrom-Json -AsHashtable
        $namedirs.Contains("main") | Should -Be $true
        $namedirs.Contains("dc") | Should -Be $false

    }

    It "wln" -Tag "wln" {
        Set-Location $PSScriptRoot/dk_utest
        New-Item -ItemType Directory a\b\c -Force

        if ((-not $IsWindows) -and (-not $IsWSL)) {
            Write-Warning "wln is invalid in pure Linux system, skip this test"
            return
        }
        $pwd_wr = [wurin]::new($PWD.Path)
        if (-not $pwd_wr.uri_win) {
            Throw "It should be in windows file system!"
        }

        dk.ps1 wln a/b/c .
        dk.ps1 wln a/b e -shortcut
        Test-Path c | Should -Be $true
        (Get-Item c).Attributes -match "ReparsePoint" | Should -Be $true
        Test-Path e.lnk | Should -Be $true
    }

    AfterAll {
        Set-Location $PSScriptRoot
        Remove-Item dk_utest -Recurse -Force
    }

}