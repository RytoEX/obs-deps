param(
    [string] $Name = 'libogg',
    [string] $Version = '1.3.6',
    [string] $Uri = 'https://github.com/xiph/ogg.git',
    [string] $Hash = "be05b13e98b048f0b5a0f5fa8ce514d56db5f822",
    [array] $Targets = @('x64', 'arm64')
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

function Clean {
    Set-Location $Path
    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        '-DINSTALL_DOCS:BOOL=OFF'
        '-DBUILD_TESTING:BOOL=OFF'
        "-DBUILD_SHARED_LIBS:BOOL=$($OnOff[$script:Shared.isPresent])"
    )

    Invoke-External cmake -S . -B "build_${Target}" @Options
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $Options = @(
        '--build', "build_${Target}"
        '--config', $Configuration
    )

    if ( $VerbosePreference -eq 'Continue' ) {
        $Options += '--verbose'
    }

    $Options += @($CmakePostfix)

    Invoke-External cmake @Options
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Options = @(
        '--install', "build_${Target}"
        '--config', $Configuration
    )

    if ( $Configuration -match "(Release|MinSizeRel)" ) {
        $Options += '--strip'
    }

    Invoke-External cmake @Options
}
