#!/usr/bin/env pwsh
#Requires -Version 7

$IsWSL = $false

if ($IsLinux -and $env:WSL_DISTRO_NAME) {
    $IsWSL = $true
}

$mycmd = (Get-Process -Id $PID).CommandLine
if ($mycmd.EndsWith("pwsh") -or $mycmd.EndsWith("pwsh.exe`"")) {
    $IsSubShell = $false
}
else {
    $IsSubShell = $true
}



function simPath([string]$p) {
    if ($p.StartsWith("/")) {
        $sys = "Linux"
    }
    elseif ($p -match "[A-Z]:") {
        $sys = "Windows"
    }
    else {
        $sys = $IsWindows ? "Windows" : "Linux"
        $p = $pwd.ProviderPath + "/" + $p
    }

    # Write-Host "p=$p"

    $segments = $p -Split "\\|/"
    [System.Collections.ArrayList]$rst = @()
    foreach ($e in $segments) {
        # Write-Host "e=$e"
        if ($e -eq "." -or $e -eq "") {
            continue
        }
        elseif ($e -eq "..") {
            if ($rst.Count -eq 0) {
                Write-Error "Wrong path!" -ErrorAction Stop
            }
            $rst.RemoveAt($rst.Count - 1)
        }
        else {
            $rst.Add($e) > $null
            if ($sys -eq "Windows" -and $rst.Count -eq 1) {
                if (-not($rst[0] -match "[A-Z]:?")) {
                    Write-Error "Wrong path since windows path must start with disk symbol" -ErrorAction Stop
                }
                if ($rst[0].Length -eq 1) {
                    $rst[0] = $rst[0].ToUpper() + ":"
                }
            }
        }
    }
    if ($sys -eq "Windows") {
        if ($rst.Count -eq 0) {
            Write-Error "Wrong path: empty" -ErrorAction Stop
        }
        return ($rst -join "\")
    }
    else {
        if ($rst.Count -eq 0) {
            return "/"
        }
        return "/" + ($rst -join "/")
    }
}

function get_realpath($p) {
    $p = [wurin]::new($p)
    if (-not $p.existed()) {
        return ""
    }
    if ($IsLinux) {
        $rp = realpath $p.uri_linux
    }
    else {
        # write-host "(T) $($p.uri_linux)"
        $rp = path2win $(bash -c "realpath $($p.uri_linux)")
    }
    return $rp
}

class wurin {
    [string]$uri_linux
    [string]$uri_win

    wurin($s) {
        if ($s -is [wurin]) {
            #@ branch | copy constructor
            $this.uri_linux = $s.uri_linux
            $this.uri_win = $s.uri_win
            return
        }
        #@ branch for abstract path
        if ($s.StartsWith("/")) {
            $this.uri_linux = simPath $s
            $this.uri_win = path2win $s
        }
        elseif ($s -match "[A-Z]:\\") {
            $this.uri_win = simPath $s
            $this.uri_linux = path2wsl $s
        }
        else {
            if ($global:IsLinux) {
                $this.uri_linux = simPath $s
                $this.uri_win = path2win $this.uri_Linux
            }
            else {
                $this.uri_win = simPath $s
                $this.uri_linux = path2wsl $this.uri_win
            }
        }
        # Write-Host "new::uri_win=$($this.uri_win)"
        # Write-Host "new::uri_linux=$($this.uri_linux)"
    }

    [bool]existed() {
        if ($global:IsLinux) {
            return [bool](Test-Path $this.uri_linux)
        }
        else {
            return [bool](Test-Path $this.uri_win)
        }
    }

    [bool]issolid() {
        #@ Introduction | test if this wurin is solid, i.e., existed and not symbol link
        if (-not $this.existed()) {
            return $false
        }
        else {
            if ((Get-Item $this.uri_auto()).LinkType -eq "SymbolicLink") {
                return $false
            }
            else {
                return $true
            }
        }
    }

    [double] MB() {
        if (-not $this.issolid()) {
            return 0
        }
        elseif ($this.isdir()) {
            Write-Error "Not supported now" -ErrorAction Stop
            return 0
        }
        else {
            return ((Get-Item $this.uri_auto()).Length / 1MB)
        }
    }

    [bool] isfile() {
        if (-not $this.isvalid()) {
            return $false
        }
        else {
            if (Test-Path $this.uri_auto() -PathType Leaf) {
                return $true
            }
            else {
                return $false
            }
        }
    }
    [bool] isdir() {
        if (-not $this.isvalid()) {
            return $false
        }
        else {
            if (Test-Path $this.uri_auto() -PathType Leaf) {
                return $false
            }
            else {
                return $true
            }
        }
    }
    [string] fdtype() {
        if ($this.isfile()) {
            return "File"
        }
        elseif ($this.isdir()) {
            return "Directory"
        }
        else {
            return ""
        }
    }

    [bool]issym() {
        #@ Introduction | Test if $this denotes to a symboliclink
        if (-not $this.existed()) {
            return $false
        }
        return ((Get-Item $this.uri_auto()).LinkType -eq "SymbolicLink")
    }

    [bool]isvsym() {
        #@ Introduction | Test if $this denotes to a valid symboliclink
        if (-not $this.issym()) {
            return $false
        }
        # write-host "(D) $($this.uri_linux)"
        $target = get_realpath $this
        return (Test-Path $target)
    }

    [wurin]target() {
        if (-not $this.issym()) {
            return $this
        }
        else {
            return [wurin]::new((Get-Item $this.uri_auto()).LinkTarget)
        }
    }

    [bool]isvalid() {
        if (-not $this.existed()) {
            return $false
        }
        if ($this.issym() -and (-not $this.isvsym())) {
            return $false
        }
        return $true
    }

    [string]basename() {
        return [System.IO.Path]::GetFileName($this.uri_linux)
    }

    [string]dirname() {
        return  [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($this.uri_linux))
    }

    [wurin]directory() {
        # Write-Host "(D) enter wurin.directory $($this.uri_linux)"
        $dirpath = [IO.Path]::GetDirectoryName($this.uri_linux)
        if ($global:IsWindows) {
            $dirpath = $dirpath.Replace("\", "/")
        }
        $rst = [wurin]::new($dirpath)
        # Write-Host "(D) leave wurin.directory $($rst.uri_linux)"
        return $rst
    }

    [bool]StartsWith($wr2) {
        $wr2 = [wurin]::new($wr2)
        return $this.uri_linux.StartsWith($wr2.uri_linux)
    }


    [wurin]ReplacePrefix($wr2, $wr3) {

        $wr2 = [wurin]::new($wr2)
        $wr3 = [wurin]::new($wr3)

        $rst = [wurin]::new($this.uri_linux)

        $rst.uri_linux = $rst.uri_linux.Replace($wr2.uri_linux, $wr3.uri_linux)
        $rst.uri_win = $rst.uri_win.Replace($wr2.uri_win, $wr3.uri_win)
        return $rst
    }
    
    [string] uri_auto() {
        if ($global:IsLinux) {
            return $this.uri_linux
        }
        else {
            return $this.uri_win
        }
    }

    [bool] Equals([object]$b) {
        if ($b -is [wurin]) {
            return $this.uri_linux -eq $b.uri_linux
        }
        elseif ($b -is [string]) {
            return ($this.uri_win -eq $b) -or ($this.uri_linux -eq $b)
        }
        else {
            return $false
        }
    }

    #@ method:get_path_without_prefix | used to remove prefix, only return string
    [string] get_path_without_prefix($wr2) {
        $wr2 = [wurin]::new($wr2)
        if (-not $this.StartsWith($wr2)) {
            return ""
        }
        if ($this.Equals($wr2)) {
            return ""
        }
        return $this.uri_linux.Substring($wr2.uri_linux.Length + 1)
    }

    [wurin]copy() {
        return [wurin]::new($this.uri_linux)
    }

    [wurin] append([string]$rp) {
        #@ Introduction | $rp => relative path
        if ($rp) {
            return [wurin]::new($this.uri_linux + "/" + $rp)
        }
        else {
            return $this.copy()
        }
    }

    [System.Collections.ArrayList] listchildren() {
        if (-not $this.isdir()) {
            return $null
        }
        $rst = New-Object System.Collections.ArrayList
        Get-ChildItem $this.uri_auto() | Select-Object -ExpandProperty FullName | ForEach-Object { $rst.Add([wurin]::new($_)) }
        return $rst
    }

    [void]rename([string]$newname) {
        $bname = $this.basename()
        $this.uri_linux = $this.uri_linux.Substring(0, $this.uri_linux.Length - $bname.Length - 1) + "/" + $newname
        $this.uri_win = $this.uri_win.Substring(0, $this.uri_win.Length - $bname.Length - 1) + "\" + $newname
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
        return (simPath $path_wsl)
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
    return (simPath $path_win)
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

enum lurric_locType{
    Null
    None
    ALL  # solid directory in both R, O & B
    O2R  # solid entity in O, linked in R
    B2R  # solid entity in B, linked in R
    O1R  # solid entity in O, but parent directory is linked in R
    B1R  # solid entity in B, but parent directory is linked in R
    R    # only entity in R, can be either solid or symlink
    S    # solid entity in S only
    O    # only in O, maybe parent uri is linked in R
    B    # only in B, maybe parent uri is linked in R
}

enum lurric_fdType{
    None
    File
    Directory
}

class lurricNotInRR: System.Exception {
    lurricNotInRR([string]$msg): base($msg) {}
}

class lurric {
    #@ Introduction | Local, URI, Recroot, Cloud => lurric
    static $rrR = [wurin]::new("D:\recRoot\Roadelse")
    static $rrO = [wurin]::new("C:\Users\mercu\OneDrive\recRoot\Roadelse")
    static $rrB = [wurin]::new("D:\BaiduSyncdisk\recRoot\Roadelse")
    static $rrS = [wurin]::new("D:\recRoot\StaticRecall")
    [string]$uri  #@ exp | //relative-path
    [wurin]$uriR
    [wurin]$uriO
    [wurin]$uriB
    [wurin]$uriS
    [lurric_fdType]$fdType
    [lurric_locType]$locType
    [System.Collections.ArrayList]$soliduris
    [bool]$echo_only = $false


    static [string] resolve_rruri($fp) {
        #@ Introduction | used to resolve relative path based on RR for given fullpath, return "" if not within luRRic structure
        $fp = [wurin]::new($fp)

        if ($fp.StartsWith([lurric]::rrR)) {
            return "//" + $fp.get_path_without_prefix([lurric]::rrR)
        }
        elseif ($fp.StartsWith([lurric]::rrO)) {
            return "//" + $fp.get_path_without_prefix([lurric]::rrO)
        }
        elseif ($fp.StartsWith([lurric]::rrB)) {
            return "//" + $fp.get_path_without_prefix([lurric]::rrB)
        }
        elseif ($fp.StartsWith([lurric]::rrS)) {
            return "//" + $fp.get_path_without_prefix([lurric]::rrS)
        }
        else {
            return ""
            # throw [lurricNotInRR]::new("Error! Given path doesn't belong to lurric structure: $($fp.uri_auto())")
        }
    }


    lurric($s) {
        #@ Introduction | 1. resolve abspath; 2. resolve existed relpath based on RR; 3. resolve existed relpath based on pwd, throw error if not in RR; 4. resolve un-existed relpath based on RR

        #@ Main
        #@ .Get-uri

        if ($s -is [lurric]) {
            $this.uri = $s.uri
            $this.render8uri()  #@ exp | render other attributes by $this.uri
            return
        }

        if ($s -is [wurin]) {
            $s = $s.uri_auto()
        }

        if ($s -match "^//") {
            #@ branch | Receive lurric uri directly
            $this.uri = "/" + (simPath $s.Substring(1))
        }
        elseif ($s -match "^[A-Z]:" -or $s.StartsWith("/")) {
            $this.uri = [lurric]::resolve_rruri($s)
        }

        else {
            $fp_by_pwd = [wurin]::new($pwd.ProviderPath + "/" + $s)
            $this.uri = [lurric]::resolve_rruri($fp_by_pwd)
        }
        # $this.uri = "//" + $this.uri
        # write-host "(T) uri=$($this.uri)"
        if (-not $this.uri) {
            throw [lurricNotInRR]::new("Error! Given path doesn't belong to lurric structure: $s")
        }

        #@ Post
        $this.render8uri()  #@ exp | render other attributes by $this.uri
    }

    [void]render8uri() {
        $this.uriR = ([lurric]::rrR).append($this.uri.Substring(2))
        $this.uriO = ([lurric]::rrO).append($this.uri.Substring(2))
        $this.uriB = ([lurric]::rrB).append($this.uri.Substring(2))
        $this.uriS = ([lurric]::rrS).append($this.uri.Substring(2))

        $this.fdType = $this._get_fdtype()
        $this.locType = $this._get_locType()
        $this.soliduris = $this._get_soliduris()
    }

    [bool]existed() {
        if ($this.uriR.existed()) {
            return $true
        }
        elseif ($this.uriO.existed()) {
            return $true
        }
        elseif ($this.uriB.existed()) {
            return $true
        }
        elseif ($this.uriS.existed()) {
            return $true
        }
        return $false
    }

    [bool] issolid() {
        if ($this.uriR.issolid()) {
            return $true
        }
        elseif ($this.uriO.issolid()) {
            return $true
        }
        elseif ($this.uriB.issolid()) {
            return $true
        }
        elseif ($this.uriS.issolid()) {
            return $true
        }
        return $false
    }

    [void]rename([string]$newname) {
        if (-not $this.existed()) {
            Write-Warning "Call lurric.rename on a non-existed object"
            return
        }
        $uriR_ori = $this.uriR.uri_auto()
        $uriO_ori = $this.uriO.uri_auto()
        $uriB_ori = $this.uriB.uri_auto()
        $uriS_ori = $this.uriS.uri_auto()

        if (-not $this.echo_only) {
            $this.uriR.rename($newname)
            $this.uriO.rename($newname)
            $this.uriB.rename($newname)
            $this.uriS.rename($newname)
        }
        # write-host "(T) $($this.locType.GetType())"
        # write-host $this.uriR.uri_auto()
        switch ($this.locType) {
            ([lurric_locType]::R) {
                $this.osrun("Rename-Item -Path $uriR_ori -NewName $newname")
            }
            ([lurric_locType]::O) {
                $this.osrun("Rename-Item -Path $uriO_ori -NewName $newname")
            }
            ([lurric_locType]::B) {
                $this.osrun("Rename-Item -Path $uriB_ori -NewName $newname")
            }
            ([lurric_locType]::O1R) {
                $this.osrun("Rename-Item -Path $uriO_ori -NewName $newname")
            }
            ([lurric_locType]::B1R) {
                $this.osrun("Rename-Item -Path $uriB_ori -NewName $newname")
            }
            ([lurric_locType]::B2R) {
                $this.osrun("Rename-Item -Path $uriB_ori -NewName $newname")
                $this.osrun("Remove-Item -Path $uriR_ori -Force")
                $this.osrun("New-Item -ItemType SymbolicLink -Path $($this.uriR.uri_auto()) -Target $($this.uriB.uri_auto()) -Force")
            }
            ([lurric_locType]::O2R) {
                $this.osrun("Rename-Item -Path $uriO_ori -NewName $newname")
                $this.osrun("Remove-Item -Path $uriR_ori -Force")
                $this.osrun("New-Item -ItemType SymbolicLink -Path $($this.uriR.uri_auto()) -Target $($this.uriO.uri_auto()) -Force")
            }
            ([lurric_locType]::ALL) {
                if (Test-Path $uriR_ori) {
                    $this.osrun("Rename-Item -Path $uriR_ori -NewName $newname")
                }
                if (Test-Path $uriO_ori) {
                    $this.osrun("Rename-Item -Path $uriO_ori -NewName $newname")
                }
                if (Test-Path $uriB_ori) {
                    $this.osrun("Rename-Item -Path $uriB_ori -NewName $newname")
                }
                if (Test-Path $uriS_ori) { 
                    $this.osrun("Rename-Item -Path $uriS_ori -NewName $newname")
                }
            }
            default {
                Write-Error "Unsupported type: $($this.locType)" -ErrorAction Stop
            }
        }
    }

    [lurric_fdType]_get_fdtype() {
        if (-not $this.existed()) {
            return [lurric_fdType]::None
        }
        $uritypes = New-Object System.Collections.Generic.HashSet[string]
        $uritypes.Add($this.uriR.fdtype())
        $uritypes.Add($this.uriO.fdtype())
        $uritypes.Add($this.uriB.fdtype())
        $uritypes.Add($this.uriS.fdtype())
        if ($uritypes.Contains("File") -and $uritypes.Contains("Directory")) {
            Write-Error "This lurric owns both file and directory in different branches" -ErrorAction Stop
        }
        if ($uritypes.Count -eq 1 -and $uritypes.Contains("")) {
            return [lurric_fdType]::None
        }
        if ($uritypes.Contains("File")) {
            return [lurric_fdType]::File
        }
        if ($uritypes.Contains("Directory")) {
            return [lurric_fdType]::Directory
        }
        Write-Error "Should Never arrive here" -ErrorAction Stop
        return [lurric_fdType]::None
    }

    [System.Collections.ArrayList]_get_soliduris() {
        if ($this.locType -eq [lurric_locType]::Null) {
            Write-Error "run `$this._get_locType first! Or, don't run this function manually" -ErrorAction Stop
        }
        if (([string]$this.locType).StartsWith("O")) {
            return [System.Collections.ArrayList]@($this.uriO)
        }
        if (([string]$this.locType).StartsWith("B")) {
            return [System.Collections.ArrayList]@($this.uriB)
        }
        if ($this.locType -eq [lurric_locType]::R) {
            return [System.Collections.ArrayList]@($this.uriR)
        }
        if ($this.locType -eq [lurric_locType]::ALL) {
            $rst = New-Object System.Collections.ArrayList
            if ($this.uriR.issolid()) {
                $rst.Add($this.uriR)
            }
            if ($this.uriO.issolid()) {
                $rst.Add($this.uriO)
            }
            if ($this.uriB.issolid()) {
                $rst.Add($this.uriB)
            }
            if ($this.uriS.issolid()) {
                $rst.Add($this.uriS)
            }
            # write-host "(T) $($rst.Count)"
            return $rst
        }
        return $null
    }

    [lurric_locType]_get_locType() {
        if (-not $this.existed()) {
            return [lurric_locType]::None
        }
        # Write-Host "cp2222222222222"

        if ($this.uriR.issolid()) {
            #@ branch | solid rr-R
            if ($this.uriO.issolid()) {
                if ((get_realpath $this.uriR) -eq (get_realpath $this.uriO)) {
                    return [lurric_locType]::O1R
                }
                elseif ($this.isfile()) {
                    Write-Error "Error multiple solid files in ROBS" -ErrorAction Stop
                }
            }
            elseif ($this.uriB.issolid()) {
                if ((get_realpath $this.uriR) -eq (get_realpath $this.uriB)) {
                    return [lurric_locType]::B1R
                }
                elseif ($this.isfile()) {
                    Write-Error "Error multiple solid files in ROBS" -ErrorAction Stop
                }
            }

            if ($this.isfile()) {
                return [lurric_locType]::R
            }
            else {
                if ($this.uriO.issolid() -or $this.uriB.issolid() -or $this.uriS.issolid()) {
                    return [lurric_locType]::ALL
                }
                else {
                    return [lurric_locType]::R
                }
            }
        }
        elseif ($this.uriR.existed()) {
            #@ branch | symlink rr-R
            # Write-Host "cp1111111111"
            $lktar = (Get-Item $this.uriR.uri_auto()).LinkTarget
            if (-not (Test-Path $lktar)) {
                Write-Warning "Find invalid symlink: $($this.uriR.uri_auto()), please handle it manually"
                return [lurric_locType]::None
            }
            else {
                # Write-Host "lktar=$lktar"
                # Write-Host "uriO=$($this.uriO.uri_auto())"
                if ($lktar -eq $this.uriO.uri_auto()) {
                    return [lurric_locType]::O2R
                }
                elseif ($lktar -eq $this.uriB.uri_auto()) {
                    return [lurric_locType]::B2R
                }
                else {
                    if ($this.uriO.existed()) {
                        # -or $this.uriB.existed()) {
                        Write-Error "Wrong status for $($this.uri), Please check it mansually!"
                        return [lurric_locType]::None
                    }
                    return [lurric_locType]::R
                }
            }
        }
        else {
            #@ branch | no rr-R
            if ($this.uriO.issolid()) {
                #@ branch | in rr-O
                if ($this.uriB.issolid()) {
                    Write-Error "own both O and B for $($this.uri), Please check it manually"
                    return [lurric_locType]::None
                }
                return [lurric_locType]::O
            }
            elseif ($this.uriB.issolid()) {
                #@ branch | in rr-B
                return [lurric_locType]::B
            } 
        }
        return [lurric_locType]::None
    }

    [bool]isfile() {
        return $this.fdType -eq [lurric_fdType]::File
    }
    [bool]isdir() {
        return $this.fdType -eq [lurric_fdType]::Directory
    }

    [double]MB() {
        if (-not $this.isfile()) {
            Write-Warning "lurric.MB() Only Support File now"
            return 0
        }
        return $this.soliduris[0].MB()
    }

    [string]basename() {
        return $this.uriR.basename()
    }

    [System.Collections.ArrayList]listchildren() {
        if (-not $this.isdir()) {
            return $null
        }

        $rst = New-Object System.Collections.ArrayList
        foreach ($d in $this.soliduris) {
            $d.listchildren() | ForEach-Object { $rst.Add([lurric]::new($_)) }
        }

        return $rst
    }

    [lurric]copy() {
        $rst = [lurric]::new($this)
        return $rst
    }

    [lurric]parent() {
        # write-host "(D) $($this.uriR.directory().uri_auto())"
        return [lurric]::new($this.uriR.directory())
    }

    [lurric]get_ch([string]$chname) {
        $newlr = [lurric]::new($this.uriR.append($chname))
        if ($newlr.existed()) {
            return $newlr
        }
        return $null
    }

    [HashTable]read_rcf([bool]$recursive) {
        $rcf = New-Object hashtable
        $lrT = $this.copy()
        # write-host "(D) Entering read_rcf for $($this.uri), lrT.uri=$($lrT.uri)"
        while ($lrT.uri.Length -gt 2) {
            # write-host "looping $($lrT.uri)"
            $lr_rcf = $lrT.get_ch(".rrconf")
            if ($null -ne $lr_rcf) {
                # write-host "reading $($lr_rcf.uri)"
                Update-Hashtable $rcf (Get-Content $lr_rcf.soliduris[0].uri_auto() | ConvertFrom-Json -AsHashtable)
            }
            if (-not $recursive) {
                break
            }
            $lrT = $lrT.parent()
        }
        return $rcf
    }

    [lurric_locType]query_locType() {
        return $this.query_locType($null)
    }

    [lurric_locType]query_locType([object]$rcf) {
        if (-not $this.existed()) {
            return [lurric_locType]::None
        }

        if ($null -eq $rcf) {
            $rcf = $this.read_rcf($true)
        }
        else {
            Update-Hashtable $rcf $this.read_rcf($false)
        }
        if (([string]$this.locType).Contains("1")) {
            return $this.locType
        }

        $bname = $this.basename()
        #@ rule 1, from name
        if ($bname.StartsWith("O..")) {
            if ($this.locType -ne [lurric_locType]::R) {
                Write-Error "Error! O... entities must be in locType:R" - -ErrorAction Stop
            }
            $this.rename($bname.Substring(3))
            return [lurric_locType]::O2R
        }
        elseif ($bname.StartsWith("B..")) {
            if ($this.locType -ne [lurric_locType]::R) {
                Write-Error "Error! B... entities must be in locType:R" - -ErrorAction Stop
            }
            $this.rename($bname.Substring(3))
            return [lurric_locType]::B2R
        }
        elseif ($bname.StartsWith("R..")) {
            if ($this.locType -ne [lurric_locType]::R) {
                Write-Error "Error! R... entities must be in locType:R" - -ErrorAction Stop
            }
            $this.rename($bname.Substring(3))
            return [lurric_locType]::R
        }

        #@ rule 2, for external shortcut-links. symlink will return None at the beginning
        if ($bname.EndsWith(".lnk")) {
            return [lurric_locType]::R
        }
        # write-host "cp8888888888"
        # write-host $rcf.ManualStatus

        #@ rule 2, from rcf
        if ($rcf.Contains("ManualStatus") -and $rcf.ManualStatus.Contains($this.basename())) {
            # write-host "Gotcha $($this.basename()) : " + $rcf.ManualStatus[$this.basename()]
            return [lurric_locType]($rcf.ManualStatus[$this.basename()])
        }
        #@ default rules
        if ($this.locType -eq [lurric_locType]::O -or $this.locType -eq [lurric_locType]::O2R) {
            return [lurric_locType]::O2R
        }
        if ($this.locType -eq [lurric_locType]::B -or $this.locType -eq [lurric_locType]::B2R) {
            return [lurric_locType]::B2R
        }
        
        # Write-Host "(D) MB=$($this.MB())"

        if ($this.isdir()) {
            return [lurric_locType]::ALL
        }
        elseif ($this.MB() -lt 5) {
            return [lurric_locType]::O2R
        }
        elseif ($this.MB() -lt 200) {
            return [lurric_locType]::B2R
        }
        else {
            return [lurric_locType]::R
        }
    }

    [void]osrun($s) {
        Write-Host "os-run: $s"
        $this.tryrun($s)
    }

    [void]tryrun($s) {
        if (-not $this.echo_only) {
            Invoke-Expression $s
        }
    }

    [void]reloc() {
        $this.reloc($this.query_locType())
    }

    [void]reloc([lurric_locType]$newST) {
        $curST = $this.locType
        if (-not $this.existed()) {
            return
        }

        if ($this.locType -eq [lurric_locType]::None) {
            Write-Warning "Skipping locType:None for $($this.uri)" 
        }

        if (([string]$newST).Contains("1")) {
            return
        }

        Write-Host "`e[33m re-locate `e[0m $($this.uri) from $($this.locType) to $($newST)"

        if ($newST -eq [lurric_locType]::ALL) {
            $curST = $this.locType
            if ($this.isfile()) {
                Write-Error "Cannot change File to ORB (Directory)" -ErrorAction Stop
            }
            if ($this.uriR.issym()) {
                $this.osrun("Remove-Item -Path $($this.uriR.uri_auto()) -Force")
            }
            if (-not (Test-Path $this.uriR.uri_auto())) {
                $this.osrun("New-Item -ItemType Directory $($this.uriR.uri_auto()) -Force")
            }
            if (-not (Test-Path $this.uriO.uri_auto())) {
                $this.osrun("New-Item -ItemType Directory $($this.uriO.uri_auto()) -Force")
            }
            if (-not (Test-Path $this.uriB.uri_auto())) {
                $this.osrun("New-Item -ItemType Directory $($this.uriB.uri_auto()) -Force")
            }
            $this.listchildren() | ForEach-Object {
                $_.set_locType($_.query_locType())
            }
        }
        elseif ($curST -eq $newST) {
            if ($curST -eq [lurric_locType]::O2R) {
                if ($this.uriR.issym() -and $this.uriR.target -eq $this.uriO) {} else {
                    $this.osrun("New-Item -ItemType SymbolicLink -Path $($this.uriR.uri_auto()) -Target $($this.uriO.uri_auto()) -Force")
                }
            }
            elseif ($curST -eq [lurric_locType]::B2R) {
                if ($this.uriR.issym() -and $this.uriR.target -eq $this.uriO) {} else {
                    $this.osrun("New-Item -ItemType SymbolicLink -Path $($this.uriR.uri_auto()) -Target $($this.uriB.uri_auto()) -Force")
                }
            }
        }
        elseif ($curST -eq [lurric_locType]::R -and $newST -eq [lurric_locType]::O2R) {
            $this.osrun("New-Item -ItemType Directory -Path $($this.uriO.directory().uri_auto()) -Force")
            $this.osrun("Move-Item -Path $($this.uriR.uri_auto()) -Destination $($this.uriO.uri_auto()) -Force")
            $this.osrun("New-Item -ItemType SymbolicLink -Path $($this.uriR.uri_auto()) -Target $($this.uriO.uri_auto()) -Force")
        }
        elseif ($curST -eq [lurric_locType]::R -and $newST -eq [lurric_locType]::B2R) {
            $this.osrun("New-Item -ItemType Directory -Path $($this.uriB.directory().uri_auto()) -Force")
            $this.osrun("Move-Item -Path $($this.uriR.uri_auto()) -Destination $($this.uriB.uri_auto()) -Force")
            $this.osrun("New-Item -ItemType SymbolicLink -Path $($this.uriR.uri_auto()) -Target $($this.uriB.uri_auto()) -Force")
        }
        elseif ($curSt -eq [lurric_locType]::O -and $newST -eq [lurric_locType]::O2R) {
            $this.osrun("New-Item -ItemType SymbolicLink -Path $($this.uriR.uri_auto()) -Target $($this.uriO.uri_auto()) -Force")
        }
        elseif ($curSt -eq [lurric_locType]::B -and $newST -eq [lurric_locType]::B2R) {
            $this.osrun("New-Item -ItemType SymbolicLink -Path $($this.uriR.uri_auto()) -Target $($this.uriB.uri_auto()) -Force")
        }
        else {
            Write-Error "To-Be-Dev! Stop now" -ErrorAction Stop
        }
        $this.locType = $newST

        return
    }

    [void]show_status([string]$goto, [bool]$open) {
        function checkE {
            param(
                [wurin]$p
            )
            if ($p.existed()) {
                return "`e[32m√`e[0m"
            }
            else {
                return "`e[31m×`e[0m"
            }
        }
        function existSymbol([wurin]$p) {
            if ($pwd.ProviderPath.StartsWith($p.uri_auto())) {
                return "*"
            }
            else {
                return " "
            }
        }
    
        Write-Host @"
Roadelse    `t($(checkE $this.uriR))$(existSymbol $this.uriR) : $($this.uriR.uri_auto())
OneDrive    `t($(checkE $this.uriO))$(existSymbol $this.uriO) : $($this.uriO.uri_auto())
BaiduSync   `t($(checkE $this.uriB))$(existSymbol $this.uriB) : $($this.uriB.uri_auto())
StaticRecall`t($(checkE $this.uriS))$(existSymbol $this.uriS) : $($this.uriS.uri_auto())
"@

        if ($goto) {
            [System.Collections.ArrayList]$dirs2go = @()
            if ($goto -match "a") {
                $dirs2go = $this.uriR.uri_auto(), $this.uriO.uri_auto(), $this.uriB.uri_auto(), $this.uriS.uri_auto()
            }
            else {
                if ($goto -match "r") {
                    $dirs2go.Add($this.uriR.uri_auto()) > $null
                }
                if ($goto -match "o") {
                    $dirs2go.Add($this.uriO.uri_auto()) > $null
                }
                if ($goto -match "b") {
                    $dirs2go.Add($this.uriB.uri_auto()) > $null
                }
                if ($goto -match "s") {
                    $dirs2go.Add($this.uriS.uri_auto()) > $null
                }
            }
            # Write-Output $dirs2go

            if ($goto.Count -eq 0) {
                Write-Error "Error! param:`$goto doesn't contain any of r, o, b, s, a" -ErrorAction Stop
            }
    
            # ~~~~~~~~~~ if $open, open the file explorer
            if ($open) {
                $dirs2go | ForEach-Object {
                    if ($IsWindows) {
                        Invoke-Item $_.uri_win 
                    }
                    else {
                        pwsh.exe -c "Invoke-Item $($_.uri_win)"
                    }
                } 
            }
            else {
                if (-not $global:IsSubShell) {
                    Set-Location $dirs2go[0].uri_auto()
                }
                else {
                    Write-Host "cd $($dirs2go[0].uri_auto())"
                }
            }
        }

    }
}