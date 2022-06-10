param(
    [string] $Name = 'qt5',
    [string] $Version = '5.15.2',
    [string] $Uri = 'https://github.com/qt/qt5.git',
    [string] $Hash = '9b43a43ee96198674060c6b9591e515e2d27c28f',
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/Qt5/win/0001-QTBUG-74606.patch"
            HashSum = "BAE8765FC74FB398BC3967AD82760856EE308E643A8460C324D36A4D07063001"
        }
    )
)

# References:
# 1: https://wiki.qt.io/Building_Qt_5_from_Git
# 2: https://doc.qt.io/qt-5/windows-building.html
# 3: https://doc.qt.io/qt-5/configure-options.html#source-build-and-install-directories
# 4: https://doc.qt.io/qt-6.2/windows-building.html

# Per [2]:
# Note: The install path must not contain any spaces or Windows specific file system characters.

# Per [4]:
# Note: The path to the source directory must not contain any spaces or Windows specific file system characters. The
# path should also be kept short. This avoids issues with too long file paths in the compilation phase.

$InstallSubDir = "msvc2019"
if ( "${Target}" -eq "x64" ) {
    $InstallSubDir = "msvc2019_64"
}

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path

    # Download jom if not present and check its hash.
    Invoke-SafeWebRequest -Uri "https://download.qt.io/official_releases/jom/jom_1_1_3.zip" -HashFile "${PSScriptRoot}/checksums/jom-1.1.3.zip.sha256" -CheckExisting
    Expand-ArchiveExt -Path "jom_1_1_3.zip" -DestinationPath "jom" -Force

    $VSData = Find-VisualStudio
    if ( $VSData.Version -ge 16.0 -and $VSData.Version -lt 17 ) {
        $InstallSubDir = $InstallSubDir
    } elseif ( $VSData.Version -ge 17.0 -and $VSData.Version -lt 18 ) {
        $InstallSubDir = $InstallSubDir -replace "2019", "2022"
    }

    New-Item -ItemType "directory" -Path "qt5_build\${Version}\${Target}" -Force
    New-Item -ItemType "directory" -Path "$($ConfigData.OutputPath)\${InstallSubDir}" -Force

    # Run init-repository perl script.
    # This will fail if any of the repos are dirty (uncommitted patches).
    Set-Location qt5

    # Reset/Clean here to prevent init-repository from failing.
    Invoke-External git submodule foreach --recursive "git clean -dfx"
    Invoke-External git clean -dfx

    Check-GitUser
    $Options = @(
        '--module-subset', 'qtbase,qtimageformats,qtmultimedia,qtsvg,qtwinextras'
        '--force'
    )
    Invoke-External perl init-repository @Options
}

function Clean {
    Set-Location $Path

    # git clean?
    # only need if building in-tree, but safe enough to do either way
    Invoke-External git submodule foreach --recursive "git clean -dfx"
    Invoke-External git clean -dfx

    Set-Location ".."
    Remove-Item "qt5_build\${Version}\${Target}\*" -Recurse -Force
    Remove-Item "$($ConfigData.OutputPath)\${InstallSubDir}\*" -Recurse -Force
}

function Patch {
    Log-Information "Patch (${Target})"
    Set-Location $Path

    $Patches | ForEach-Object {
        $Params = $_
        Safe-Patch @Params
    }

    Set-Location qtbase
    Check-GitUser
    git add .
    git commit -m "Simple fix for QTBUG-74606"
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $BuildPath = "$($ConfigData.OutputPath)\${InstallSubDir}"
    Set-Location "..\qt5_build\${Version}\${Target}"

    $QtBuildConfiguration = '-release'
    if ( $Configuration -eq 'Release' ) {
        $QtBuildConfiguration = '-release'
    } elseif ( $Configuration -eq 'RelWithDebInfo' ) {
        $QtBuildConfiguration = '-release -force-debug-info'
    } elseif ( $Configuration -eq 'Debug' ) {
        $QtBuildConfiguration = '-debug'
    } elseif ( $Configuration -eq 'MinSizeRel' ) {
        $QtBuildConfiguration = '-release'
    }

    $BuildCommand = "..\..\..\qt5\configure -opensource -confirm-license ${QtBuildConfiguration} -no-strip -nomake examples -nomake tests -no-compile-examples -schannel -no-dbus -no-freetype -no-harfbuzz -no-icu -no-feature-itemmodeltester -no-feature-printdialog -no-feature-printer -no-feature-printpreviewdialog -no-feature-printpreviewwidget -no-feature-sql -no-feature-sqlmodel -no-feature-testlib -no-sql-db2 -no-sql-ibase -no-sql-mysql -no-sql-oci -no-sql-odbc -no-sql-psql -no-sql-sqlite2 -no-sql-sqlite -no-sql-tds -DQT_NO_PDF -DQT_NO_PRINTER -mp -prefix ${BuildPath}"

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "."
        BuildCommand = "${BuildCommand}"
        Target = $Target
        HostArchitecture = $Target
    }

    Invoke-DevShell @Params
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    Set-Location ".."
    Copy-Item "jom\jom.exe" "qt5_build\${Version}\${Target}\jom.exe"

    Set-Location "qt5_build\${Version}\${Target}"

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "."
        BuildCommand = ".\jom.exe"
        Target = $Target
        HostArchitecture = $Target
    }

    Invoke-DevShell @Params
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    Set-Location "..\qt5_build\${Version}\${Target}"

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "."
        BuildCommand = ".\jom.exe install"
        Target = $Target
        HostArchitecture = $Target
    }

    Invoke-DevShell @Params
}

function Fixup_ {
    Log-Information "Fixup (${Target})"
    Set-Location $Path

    if ( $Configuration -ne 'RelWithDebInfo' ) {
        return
    }

    Set-Location "..\qt6_build\${Version}\${InstallSubDir}"
    $QtInstallDir = (Get-Location | Convert-Path)
    Set-Location ".."
    New-Item -ItemType "directory" -Path "${InstallSubDir}_pdbs" -Force
    Set-Location "${InstallSubDir}_pdbs"
    $ReleasePdbInstallDir = (Get-Location | Convert-Path)
    Set-Location "..\${InstallSubDir}"

    # Build a list of all PDBs whose filenames:
    # * do not end with the letter "d"
    #   * except for files that end in the letters "2d" ("qdirect2d.pdb")
    #   * except for files that end in the letters "backend" ("qcertonlybackend.pdb" and "qschannelbackend.pdb")
    $ReleasePdbFiles = Get-ChildItem -Filter "*.pdb" -File -Recurse | Where-Object { $_.Name -like "*.pdb" -and ( $_.Name -notlike "*d.pdb" -or $_.Name -like "*2d.pdb" -or $_.Name -like "*backend.pdb" ) }

    $DestinationDirRelativePaths = ( $ReleasePdbFiles | ForEach-Object { $_.DirectoryName } | Sort-Object -Unique ).Replace("${QtInstallDir}\", "")

    # Make directories for release PDBs
    $DestinationDirRelativePaths | ForEach-Object { New-Item -Name "$_" -Path "${ReleasePdbInstallDir}" -ItemType directory -Force }

    # Move PDBs to separate directories
    $ReleasePdbFiles | ForEach-Object { Move-Item $_.FullName $_.FullName.Replace("${QtInstallDir}", "${ReleasePdbInstallDir}") }
}
