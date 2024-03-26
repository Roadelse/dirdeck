#Requires -Version 7


#@ <Pre-knowledge>
#@ use "-Tag" to test selective blocks
#@ </Pre-knowledge>


BeforeAll {
    . $PSScriptRoot\..\bin\base.ps1
    $testDir = Join-Path $PSScriptRoot "ade.utest"
    Write-Host "`e[33m-- testDir=$testDir`e[0m"
    New-Item -ItemType Directory -Path $testDir -Force
}

AfterAll {
    Set-Location $testDir/..
    Remove-Item -Path $testDir -Force -Recurse
}

Describe "functions" -Tag "func" {
    It "function: get_realpath" -Tag "get_realpath" {
        Set-Location $testDir
        New-Item -ItemType Directory -Path "d1" -Force
        New-Item -ItemType SymbolicLink -Path "d2" -Target "d1" -Force
        New-Item -ItemType File -Path "d1/f1" -Force
        $rp = get_realpath("d2/f1")
        $rp | Should -Be (Join-Path $testDir "d1/f1")

        Remove-Item -Path "d1" -Force -Recurse
        Remove-Item -Path "d2" -Force
    }

    It "function: simPath" -Tag "simPath" {
        simPath "/" | Should -Be "/"
        simPath "C:\" | Should -Be "C:"
        simPath "D:\recRoot\Roadelse\" | Should -Be "D:\recRoot\Roadelse"
        simPath "//a/b/c/../../e/" | Should -Be "/a/e"
        simPath "/." | Should -Be "/"
    }

    It "function: path2win/wsl" -Tag "path2ww" {
        path2win "/mnt/c/" | Should -Be "C:"
        path2win "/mnt/c/asd/" | Should -Be "C:\asd"
    }
}

Describe "class wurin" -Tag "wurin" {
    It "new" -Tag "wurin-new" {
        $wr1 = [wurin]::new(".")
        $wr1.uri_auto() | Should -Be $pwd.ProviderPath
        $wr2 = [wurin]::new("/")
        $wr2.uri_linux | Should -Be "/"
        $wr2.uri_win | Should -Be ""
        $wr3 = [wurin]::new("D:")
        $wr3.uri_win | Should -Be "D:"
        $wr4 = [wurin]::new("\")
        $wr4.uri_auto() | Should -Be $pwd.ProviderPath
    }
    It "existed" {
        $wr1 = [wurin]::new(".")
        $wr2 = [wurin]::new("ahacq")
        $wr1.existed() | Should -Be $true
        $wr2.existed() | Should -Be $false
    }
    It "issolid" {
        Set-Location $testDir

        New-Item -ItemType File -Path "ade.f1"
        New-Item -ItemType SymbolicLink -Path "ade.l1" -Target "./ade.f1"
        $wr1 = [wurin]::new("ade.f1")
        $wr1.issolid() | Should -Be $true
        $wr1 = [wurin]::new("ade.l1")
        $wr1.issolid() | Should -Be $false

        Remove-Item -Path "ade.f1" -Force
        Remove-Item -Path "ade.l1" -Force
    }

    It "MB" {
        Set-Location $testDir
        "123456789" > temp.txt
        $wr1 = [wurin]::new("temp.txt")
        [int]($wr1.MB()) | Should -Be 0
        Remove-Item -Path temp.txt -Force
    }

    It "file/directory/sym/vsym" {
        Set-Location $testDir
        New-Item -ItemType File -Path "ade.f1"
        New-Item -ItemType Directory -Path "ade.d1"
        $wr1 = [wurin]::new("ade.f1")
        $wr2 = [wurin]::new("ade.d1")
        $wr1.isfile() | Should -Be $true
        $wr2.isdir() | Should -Be $true

        New-Item -ItemType SymbolicLink -Path "ade.l1" -Target "./ade.f1"
        New-Item -ItemType SymbolicLink -Path "ade.l2" -Target "./ade.d1"
        $wr3 = [wurin]::new("ade.l1")
        $wr4 = [wurin]::new("ade.l2")
        $wr3.isfile() | Should -Be $true
        $wr4.isdir() | Should -Be $true
        $wr3.issym() | Should -Be $true
        $wr4.issym() | Should -Be $true

        New-Item -ItemType SymbolicLink -Path "ade.l3" -Target "./ade.458"
        $wr5 = [wurin]::new("ade.l3")
        $wr5.issym() | Should -Be $true
        $wr5.existed() | Should -Be $true
        $wr5.isvsym() | Should -Be $false
        $wr5.isfile() | Should -Be $false
        $wr5.isdir() | Should -Be $false
        $wr5.issolid() | Should -Be $false

        Remove-Item -Path "ade.f1" -Force
        Remove-Item -Path "ade.d1" -Force
        Remove-Item -Path "ade.l1" -Force
        Remove-Item -Path "ade.l2" -Force
        Remove-Item -Path "ade.l3" -Force
    }

    It "basename/StartsWith" {
        Set-Location $testDir
        New-Item -ItemType File -Path "ade.f1"
        $wr1 = [wurin]::new("ade.f1")
        $wr1.basename() | Should -Be "ade.f1"
        $wr1.StartsWith($testDir) | Should -Be $true
        Remove-Item -Path "ade.f1" -Force
    }

    It "ReplacePrefix" {
        Set-Location $testDir
        $wr1 = [wurin]::new("ade.d1/ade.f1")
        $wr2 = $wr1.ReplacePrefix("ade.d1", "ade.d2")
        $wr2.basename() | Should -Be "ade.f1"
        $wr2.dirname() | Should -Be "ade.d2"
    }

    It "get_path_without_prefix" {
        Set-Location $testDir
        $wr1 = [wurin]::new("ade.d1/ade.f1")
        $wr1.get_path_without_prefix("ade.d1") | Should -Be "ade.f1"
        $wr1.get_path_without_prefix("ade.d1/ade.f1") | Should -Be ""
        $wr1.get_path_without_prefix("/home/zjx") | Should -Be ""
    }

    It "append" {
        Set-Location $testDir
        $wr1 = [wurin]::new("ade.d1")
        $wr2 = $wr1.append("ade.f1")
        $wr2.uri_auto() | Should -Be (Join-Path $pwd.ProviderPath "ade.d1" "ade.f1")
    }

    It "listchildren" -Tag "wurin-listch" {
        Set-Location $PSScriptRoot
        $wr1 = [wurin]::new(".")
        $chs = $wr1.listchildren()
        # Write-Host $chs[0].uri_auto()
        $chs.Count | Should -Be 2
        $chs[1].uri_linux.EndsWith("utest.ps1") | Should -Be $true
    }

    It "rename" -Tag "wurin-rename" {
        $wr1 = [wurin]::new("hello")
        $wr1.rename("what")
        $wr1.basename() | Should -Be "what"
        $wr1.uri_linux.EndsWith("what") | Should -Be $true
        $wr1.uri_win.EndsWith("what") | Should -Be $true

        $wr2 = [wurin]::new("D:\a\b\d1")
        $wr2.rename("d2")
        $wr2.rename("d3")
        $wr2.rename("d4")
        $wr2.uri_win | Should -Be "D:\a\b\d4"
    }
}

Describe "class lurric" -Tag "lurric" {
    It "new" -Tag "lurric-new" {
        $lc1 = [lurric]::new("//.")
        $lc1.uri | Should -Be "//"
        { [lurric]::new("utest.ps1") } | Should -Throw

        $tempfile1 = Join-Path ([lurric]::rrR).uri_auto() "ade.f1"
        New-Item -ItemType File -Path $tempfile1 -Force
        $lc2 = [lurric]::new("//ade.f1")
        $lc2.uri | Should -Be "//ade.f1"
        Remove-Item $tempfile1 -Force
    }

    It "classify" {
        $fileR1 = Join-Path ([lurric]::rrR).uri_auto() "fileR1"
        $fileR2 = Join-Path ([lurric]::rrR).uri_auto() "fileR2"
        $fileO1 = Join-Path ([lurric]::rrO).uri_auto() "fileO1"
        $fileO2 = Join-Path ([lurric]::rrO).uri_auto() "fileR2"
        $fileO1_O2R = Join-Path ([lurric]::rrR).uri_auto() "fileO1"
        $dirR1 = Join-Path ([lurric]::rrR).uri_auto() "dirR1"
        $dirO1 = Join-Path ([lurric]::rrO).uri_auto() "dirO1"
        $dirO1_O2R = Join-Path ([lurric]::rrR).uri_auto() "dirO1_O2R"
        $fileO1R1 = Join-Path ([lurric]::rrR).uri_auto() "dirO1_O2R/fileO1R1"

        New-Item -ItemType File -Path $fileR1 -Force
        New-Item -ItemType File -Path $fileR2 -Force
        New-Item -ItemType File -Path $fileO1 -Force
        New-Item -ItemType File -Path $fileO2 -Force
        New-Item -ItemType SymbolicLink -Path $fileO1_O2R -Target $fileO1 -Force
        New-Item -ItemType Directory -Path $dirR1 -Force
        New-Item -ItemType Directory -Path $dirO1 -Force
        New-Item -ItemType SymbolicLink -Path $dirO1_O2R -Target $dirO1 -Force
        New-Item -ItemType File -Path $fileO1R1 -Force

        $lc1 = [lurric]::new($fileR1)
        $lc1.isfile() | Should -Be $true
        $lc1.issolid() | Should -Be $true
        $lc1.fdType | Should -Be "File"
        $lc1.locType | Should -Be "R"
        $lc1.soliduris.Count | Should -Be 1
        [object]::ReferenceEquals($lc1.soliduris[0], $lc1.uriR) | Should -Be $true

        { [lurric]::new("fileR2") } | Should -Throw

        $lc2 = [lurric]::new($fileO1)
        $lc2.isfile() | Should -Be $true
        $lc2.issolid() | Should -Be $true
        $lc2.fdType | Should -Be "File"
        $lc2.locType | Should -Be "O2R"
        $lc2.soliduris.Count | Should -Be 1
        [object]::ReferenceEquals($lc2.soliduris[0], $lc2.uriO) | Should -Be $true

        Remove-Item -Path $fileR1 -Force
        Remove-Item -Path $fileR2 -Force
        Remove-Item -Path $fileO1 -Force
        Remove-Item -Path $fileO2 -Force
        Remove-Item -Path $fileO1_O2R -Force
        Remove-Item -Path $dirR1 -Force -Recurse
        Remove-Item -Path $dirO1 -Force -Recurse
        Remove-Item -Path $dirO1_O2R -Force -Recurse
    }

    It "listchildren" -Tag "lurric-listch" {
        $dirR1 = Join-Path ([lurric]::rrR).uri_auto() "dirRO1"
        $dirO1 = Join-Path ([lurric]::rrO).uri_auto() "dirRO1"
        $fileR1 = Join-Path ([lurric]::rrR).uri_auto() "dirRO1/fileR1"
        $fileR2 = Join-Path ([lurric]::rrO).uri_auto() "dirRO1/fileR2"

        New-Item -ItemType Directory -Path $dirR1 -Force
        New-Item -ItemType Directory -Path $dirO1 -Force
        New-Item -ItemType File -Path $fileR1 -Force
        New-Item -ItemType File -Path $fileR2 -Force

        $lc1 = [lurric]::new("//dirRO1")
        $lc1.locType | Should -Be "ALL"
        $lc1.uriR.issolid() | Should -Be $true
        $lc1.uriO.issolid() | Should -Be $true
        $lc1.soliduris.Count | Should -Be 2
        $chs = $lc1.listchildren()
        # write-host $chs[0].uri
        $chs.Count | Should -Be 2
        # write-host $chs[1].uri
        $chs[0].basename() | Should -Be "fileR1"
        $chs[1].basename() | Should -Be "fileR2"

        Remove-Item -Path $dirR1 -Force -Recurse
        Remove-Item -Path $dirO1 -Force -Recurse
    }

    It "rename" -Tag "lurric-rename" {
        $fileR1 = Join-Path ([lurric]::rrR).uri_auto() "fileR1"
        New-Item -ItemType File -Path $fileR1 -Force

        $lc1 = [lurric]::new("//fileR1")
        $lc1.rename("fr2")
        $lc1.basename() | Should -Be "fr2"

        Remove-Item -Path $lc1.soliduris[0].uri_auto() -Force
    }

    It "parent" -Tag "lurric-parent" {
        $lr = [lurric]::new("//")
        # Write-Host "(D) $($lr.uriR.uri_auto())"
        { $lr.parent() } | Should -Throw -ExceptionType ([lurricNotInRR])
        $lr2 = [lurric]::new("//a/b/c/d")
        $lr3 = $lr2.parent()
        $lr3.uri | Should -Be "//a/b/c"
    }

    It "query_locType" -Tag "lurric-query" {
        $dirR1 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest/d1/d2"
        $rcf1 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest/.rrconf"
        $rcf2 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest/d1/.rrconf"

        $file1 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest/d1/d2/r1.txt"
        $file2 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest/d1/d2/r2.doc"
        $file3 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest/d1/r3.txt"
        $file4 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest/r4.doc"
        New-Item -ItemType Directory -Path $dirR1 -Force
        @{ManualStatus = @{"r1.txt" = "R"; "r2.doc" = "O2R" } } | ConvertTo-Json | Set-Content -Path $rcf1
        @{ManualStatus = @{"r3.txt" = "R"; "r4.doc" = "B2R" } } | ConvertTo-Json | Set-Content -Path $rcf2
        New-Item -ItemType File -Path $file1 -Force
        New-Item -ItemType File -Path $file2 -Force
        New-Item -ItemType File -Path $file3 -Force
        New-Item -ItemType File -Path $file4 -Force

        $lr1 = [lurric]::new($file1)
        $lr1 -ne $null | Should -Be $true
        $lr2 = [lurric]::new($file2)
        $lr3 = [lurric]::new($file3)
        $lr4 = [lurric]::new($file4)

        $lr1.read_rcf($false).Count | Should -Be 0
        $lr2.read_rcf($true).Count | Should -Be 1

        $lr1.query_locType($null) | Should -Be "R"
        $lr2.query_locType($null) | Should -Be "O2R"
        $lr3.query_locType($null) | Should -Be "R"
        $lr4.query_locType($null) | Should -Be "O2R"

        Remove-Item -Path $dirR1 -Force -Recurse
    }

    It "reloc: R->O2R" -Tag "lurric-reloc" {
        $dirR1 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest"
        $dirR1_O = Join-Path ([lurric]::rrO).uri_auto() "ade.dktest"
        $file1 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest/r1.txt"

        Remove-Item -Path $dirR1 -Force -Recurse -ErrorAction SilentlyContinue 
        Remove-Item -Path $dirR1_O -Force -Recurse -ErrorAction SilentlyContinue 
        New-Item -ItemType Directory -Path $dirR1 -Force
        New-Item -ItemType File -Path $file1 -Force

        $lr1 = [lurric]::new($file1)
        $lr1.locType | Should -Be ([lurric_locType]::R)
        $qlt = $lr1.query_locType($null)
        $qlt | Should -Be ([lurric_locType]::O2R)
        # write-host "|||||||||"
        $lr1.reloc($qlt)
        $lr1.locType | Should -Be ([lurric_locType]::O2R)
        $lr1.uriO.issolid() | Should -Be $true
        $lr1.uriR.isvsym() | Should -Be $true

        Remove-Item -Path $dirR1 -Force -Recurse
        Remove-Item -Path $dirR1_O -Force -Recurse
    }

    It "reloc: O->O2R" -Tag "lurric-reloc" {
        $dirO1 = Join-Path ([lurric]::rrO).uri_auto() "ade.dktest"
        $dirR1 = Join-Path ([lurric]::rrR).uri_auto() "ade.dktest"
        $file1 = Join-Path ([lurric]::rrO).uri_auto() "ade.dktest/r1.txt"

        Remove-Item -Path $dirR1 -Force -Recurse -ErrorAction SilentlyContinue 
        Remove-Item -Path $dirO1 -Force -Recurse -ErrorAction SilentlyContinue 
        New-Item -ItemType Directory -Path $dirO1 -Force
        New-Item -ItemType File -Path $file1 -Force

        $lr1 = [lurric]::new($file1)
        $lr1.locType | Should -Be ([lurric_locType]::O)
        $qlt = $lr1.query_locType($null)
        $qlt | Should -Be ([lurric_locType]::O2R)
        $lr1.reloc($qlt)
        $lr1.locType | Should -Be ([lurric_locType]::O2R)
        $lr1.uriO.issolid() | Should -Be $true
        $lr1.uriR.isvsym() | Should -Be $true

        Remove-Item -Path $dirR1 -Force -Recurse
        Remove-Item -Path $dirO1 -Force -Recurse
    }
}

Describe "robs.ps1" -Tag "robs" {
    BeforeAll {
        $env:PATH = "$PSScriptRoot\..\bin;" + $env:PATH
        Write-Warning "This Pester Describe is not uniform and need manual check."
    }
    It "show_help" {
        robs.ps1 -h
    }
    It "show_robs" -Tag "robs-show" -Skip {
        Set-Location ([lurric]::rrR).uri_auto()
        Write-Host @"
Should Be: 
--------------------------------------------------------------------------
Roadelse        (`e[32m√`e[0m)* : D:\recRoot\Roadelse
OneDrive        (`e[32m√`e[0m)  : C:\Users\mercu\OneDrive\recRoot\Roadelse
BaiduSync       (`e[32m√`e[0m)  : D:\BaiduSyncdisk\recRoot\Roadelse
StaticRecall    (`e[32m√`e[0m)  : D:\recRoot\StaticRecall
--------------------------------------------------------------------------
Now Get:

"@
        robs.ps1 show
        $uipt = Read-Host -Prompt "Is the result the same? ([Y]/N)"
        if ($uipt -eq "Y" -or $uipt -eq "") {

        }
        else {
            throw -ExceptionType Exception
        }
    }

}

# Describe "dirdeck unit tests" {

#     BeforeAll {
#         . .\base.ps1
#         New-Item -ItemType Directory dk_utest -Force
#         Set-Location dk_utest
#         if ($IsLinux) {
#             $env:PATH = $PSScriptRoot + ":" + $env:PATH
#         }
#         else {
#             $env:PATH = $PSScriptRoot + ";" + $env:PATH
#         }
#         $env:reSG_dat = Join-Path $PWD.Path "reSG_dat"
#     }

#     It "s/g/del/clear" -Tag "sg" {
#         Set-Location $PSScriptRoot/dk_utest
#         New-Item -ItemType Directory a\b\c -Force
#         dk.ps1 s
#         Set-Location a\b\c
#         dk.ps1 s dc
#         dk.ps1 g
#         $PWD.Path | Should -Be (Join-Path $PSScriptRoot "dk_utest")
#         dk.ps1 g dc
#         $PWD.Path | Should -Be (Join-Path $PSScriptRoot "dk_utest/a/b/c")
#         dk.ps1 g
#         dk.ps1 del dc
#         $namedirs = Get-Content $env:reSG_dat | ConvertFrom-Json -AsHashtable
#         $namedirs.Contains("main") | Should -Be $true
#         $namedirs.Contains("dc") | Should -Be $false

#     }

#     It "wln" -Tag "wln" {
#         Set-Location $PSScriptRoot/dk_utest
#         New-Item -ItemType Directory a\b\c -Force

#         if ((-not $IsWindows) -and (-not $IsWSL)) {
#             Write-Warning "wln is invalid in pure Linux system, skip this test"
#             return
#         }
#         $pwd_wr = [wurin]::new($PWD.Path)
#         if (-not $pwd_wr.uri_win) {
#             Throw "It should be in windows file system!"
#         }

#         dk.ps1 wln a/b/c .
#         dk.ps1 wln a/b e -shortcut
#         Test-Path c | Should -Be $true
#         (Get-Item c).Attributes -match "ReparsePoint" | Should -Be $true
#         Test-Path e.lnk | Should -Be $true
#     }

#     AfterAll {
#         Set-Location $PSScriptRoot
#         Remove-Item dk_utest -Recurse -Force
#     }

# }
