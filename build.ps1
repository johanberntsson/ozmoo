# build.ps1: Build script for Z-code interpreter Ozmoo
# 
# Usage:
# build.ps1 -Type z3           Build a disk image with a z3 story and the v3 terp
# build.ps1 -Type z5 -Run      Build a disk image with a z5 story and the v5 terp, then execute in Vice
# build.ps1                    -Type defaults to z5. Vice is not run.


param (
    [string]$Type = "z5",
    [switch]$Run = $false
)

# File paths. Adapt to your system.

[string] $acmeExe = "C:\ProgramsWoInstall\Acme\acme.exe"
[string] $c1541Exe = "C:\ProgramsWoInstall\WinVICE-3.1-x64\c1541.exe"
[string] $viceExe = "C:\ProgramsWoInstall\WinVICE-3.1-x64\x64.exe"

[string] $upperType = $type.ToUpper();
[string] $diskImage;

function BuildImage([string]$type) {
    & $acmeExe ("-D"+$type+"=1") -DDEBUG=1 --cpu 6510 --format cbm --outfile ozmoo ozmoo.asm           
    copy -Force d64toinf/$diskImage $diskImage
    & $c1541Exe -attach $diskImage -write ozmoo ozmoo
    Write-Output ("Successfully built disk image " + $diskImage)  
}

################
# Main program #
################

if($upperType -eq 'Z3') {
    $diskImage = 'dejavu.d64'
} elseif($upperType -eq 'Z5') {
    $diskImage = 'dragontroll.d64'
} else {
    Write-Error "Error: Type can only be z3 or z5"
    exit
}

BuildImage -type $upperType

if($Run) {
    Write-Output 'Launching Vice...'
    & $viceExe $diskImage
}
