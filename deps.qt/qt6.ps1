param(
    [string] $Name = 'qt6',
    [string] $Version = '6.3',
    [string] $Uri = 'https://github.com/qt/qt5.git',
    [string] $Hash = '9af3e106a7bb6bd4ed2b8c4d31a8d6090a582b02'
)

# References:
# 1: https://wiki.qt.io/Building_Qt_6_from_Git
# 2: https://doc.qt.io/qt-6/windows-building.html
# 3: https://doc.qt.io/qt-6/configure-options.html#source-build-and-install-directories
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
    Check-Ninja
    $Path = "qt6"
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath "$Path"

    $VSData = Find-VisualStudio
    if ( $VSData.Version -ge 16.0 -and $VSData.Version -lt 17 ) {
        $InstallSubDir = $InstallSubDir
    } elseif ( $VSData.Version -ge 17.0 -and $VSData.Version -lt 18 ) {
        $InstallSubDir = $InstallSubDir -replace "2019", "2022"
    }

    New-Item -ItemType "directory" -Path "qt6_build\${Version}\${Target}" -Force
    New-Item -ItemType "directory" -Path "$($ConfigData.OutputPath)\${InstallSubDir}" -Force

    # Run init-repository perl script.
    # This will fail if any of the repos are dirty (uncommitted patches).
    Set-Location qt6
    $Options = @(
        '--module-subset', 'qtbase,qtimageformats,qtmultimedia,qtshadertools,qtsvg'
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
    Remove-Item "qt6_build\${Version}\${Target}\*" -Recurse -Force
    Remove-Item "$($ConfigData.OutputPath)\${InstallSubDir}\*" -Recurse -Force
}

function Patch {
    Log-Information "Patch (${Target})"
    Set-Location $Path

    $Patches | ForEach-Object {
        $Params = $_
        Safe-Patch @Params
    }
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $BuildPath = "$($ConfigData.OutputPath)\${InstallSubDir}"
    Set-Location "..\qt6_build\${Version}\${Target}"

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

    $BuildCommand = "..\..\..\qt6\configure -opensource -confirm-license ${QtBuildConfiguration} -nomake examples -nomake tests -schannel -no-dbus -no-freetype -no-icu -no-openssl -no-feature-androiddeployqt -no-feature-pdf -no-feature-printsupport -no-feature-qmake -no-feature-sql -no-feature-testlib -no-feature-windeployqt -DQT_NO_PDF -prefix ${BuildPath}"

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

    Set-Location "..\qt6_build\${Version}\${Target}"

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "."
        BuildCommand = "cmake --build . --parallel"
        Target = $Target
        HostArchitecture = $Target
    }

    Invoke-DevShell @Params
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    Set-Location "..\qt6_build\${Version}\${Target}"

    $BuildCommand = 'cmake --install .'

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "."
        BuildCommand = "${BuildCommand}"
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
