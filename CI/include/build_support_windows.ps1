##############################################################################
# Windows native-compile support functions
##############################################################################
#
# This script file can be included in PowerShell build scripts for Windows.
#
##############################################################################

$CIWorkflow = "${CheckoutDir}/.github/workflows/main.yml"

$CIWorkflowJobString = Get-Content ${CIWorkflow} -Raw | Select-String "(?s)(  windows-deps-build-native.+)\n  \w" | ForEach-Object{$_.Matches.Groups[1].Value}

$CIDepsVersion = Get-Content ${CIWorkflow} | Select-String "[ ]+DEPS_VERSION_WIN: '([0-9\-]+)'" | ForEach-Object{$_.Matches.Groups[1].Value}

$BuildDirectory = "$(if (Test-Path Env:BuildDirectory) { $env:BuildDirectory } else { $BuildDirectory })"
$BuildArch = "$(if (Test-Path Env:BuildArch) { $env:BuildArch } else { $BuildArch })"
$BuildConfiguration = "$(if (Test-Path Env:BuildConfiguration) { $env:BuildConfiguration } else { $BuildConfiguration })"

$WindowsDepsVersion = "$(if (Test-Path Env:WindowsDepsVersion ) { $env:WindowsDepsVersion } else { $CIDepsVersion })"
$CmakeSystemVersion = "$(if (Test-Path Env:CMAKE_SYSTEM_VERSION) { $Env:CMAKE_SYSTEM_VERSION } else { "10.0.18363.657" })"

function Write-Status {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $output
    )

    if (!$Quiet) {
        if (Test-Path Env:CI) {
            Write-Host "[${ProductName}] ${output}"
        } else {
            Write-Host -ForegroundColor blue "[${ProductName}] ${output}"
        }
    }
}

function Write-Info {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $output
    )

    if (!$Quiet) {
        if (Test-Path Env:CI) {
            Write-Host " + ${output}"
        } else {
            Write-Host -ForegroundColor DarkYellow " + ${output}"
        }
    }
}

function Write-Step {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $output
    )

    if (!$Quiet) {
        if (Test-Path Env:CI) {
            Write-Host " + ${output}"
        } else {
            Write-Host -ForegroundColor green " + ${output}"
        }
    }
}

function Write-Error {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $output
    )

    if (Test-Path Env:CI) {
        Write-Host " + ${output}"
    } else {
        Write-Host -ForegroundColor red " + ${output}"
    }
}

function Test-CommandExists {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $Command
    )

    $CommandExists = $false
    $OldActionPref = $ErrorActionPreference
    $ErrorActionPreference = "stop"

    try {
        if (Get-Command $Command) {
            $CommandExists = $true
        }
    } Catch {
        $CommandExists = $false
    } Finally {
        $ErrorActionPreference = $OldActionPref
    }

    return $CommandExists
}

function Ensure-Directory {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $Directory
    )

    if (!(Test-Path $Directory)) {
        $null = New-Item -ItemType Directory -Force -Path $Directory
    }

    Set-Location -Path $Directory
}

function Cleanup {
}

function Caught-Error {
    Write-Error "ERROR during build step: $($args[0])"
    Cleanup
    exit 1
}

function Install-Windows-Build-Tools {
    Write-Status "Check Windows build tools"

    $ObsBuildDependencies = @(
        @("7z", "7zip"),
        @("cmake", "cmake --install-arguments 'ADD_CMAKE_TO_PATH=System'"),
        @("curl", "curl"),
        @("git", "git"),
        @("patch", "patch")
    )

    if (!(Test-CommandExists "choco")) {
        Write-Step "Install Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    Foreach($Dependency in $ObsBuildDependencies) {
        if ($Dependency -is [system.array]) {
            $Command = $Dependency[0]
            $ChocoName = $Dependency[1]
        } else {
            $Command = $Dependency
            $ChocoName = $Dependency
        }

        if ((Test-CommandExists "${Command}")) {
            Write-Status "Has ${Command}"
        } else {
            Write-Step "Install dependency ${ChocoName}..."
            Invoke-Expression "choco install -y ${ChocoName}"
        }
    }

    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-Dependencies {
    if (!$NoChoco) {
        Install-Windows-Build-Tools
    }
}

function Get-Basename {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $Path
    )

    $Separators = "\/"
    $SepArray = $Separators.ToCharArray()
    return ${Path}.Substring(${Path}.LastIndexOfAny($SepArray) + 1)
}

function Safe-Fetch {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $DOWNLOAD_URL,
        [Parameter(Mandatory=$true)]
        [String] $DOWNLOAD_HASH
    )
    if ($PSBoundParameters.Count -lt 2) {
        Caught-Error "Usage: Safe-Fetch URL HASH"
    }

    $DOWNLOAD_FILE = Get-Basename "${DOWNLOAD_URL}"
    $CURLCMD = $script:CURLCMD

    if ($NoContinue) {
        Write-Output "NoContinue is true"
        $CURLCMD = $CURLCMD.Replace("--continue-at -", "") + " ${DOWNLOAD_URL}"
    } else {
        Write-Output "NoContinue is false"
        $CURLCMD = ${CURLCMD} + " ${DOWNLOAD_URL}"
    }

    Invoke-Expression "${CURLCMD}"

    if ("${DOWNLOAD_HASH}" -eq $(Get-FileHash ${DOWNLOAD_FILE}).Hash) {
        Write-Info "${DOWNLOAD_FILE} downloaded successfully and passed hash check"
        return 0
    } else {
        Write-Error "${DOWNLOAD_FILE} downloaded successfully and failed hash check"
        return 1
    }
}

function Check-And-Fetch {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $DOWNLOAD_URL,
        [Parameter(Mandatory=$true)]
        [String] $DOWNLOAD_HASH
    )
    if ($PSBoundParameters.Count -lt 2) {
        Caught-Error "Usage: Check-And-Fetch URL HASH"
    }

    $DOWNLOAD_FILE = Get-Basename "${DOWNLOAD_URL}"

    if (Test-Path "${DOWNLOAD_FILE}" -and "${DOWNLOAD_HASH}" -eq $(Get-FileHash ${DOWNLOAD_FILE}).Hash) {
        Write-Info "${DOWNLOAD_FILE} exists and passed hash check"
        return 0
    } else {
        Safe-Fetch $SafeFetchArgs "${DOWNLOAD_URL}" "${DOWNLOAD_HASH}"
    }
}

function Git-Fetch {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $GIT_HOST,
        [Parameter(Mandatory=$true)]
        [String] $GIT_USER,
        [Parameter(Mandatory=$true)]
        [String] $GIT_REPO,
        [Parameter(Mandatory=$true)]
        [String] $GIT_REF
    )
    if ($PSBoundParameters.Count -ne 4) {
        Write-Error "Usage: Git-Fetch GIT_HOST GIT_USER GIT_REPOSITORY GIT_REF"
        exit 1
    }

    $GIT_HOST = $GIT_HOST.TrimEnd("/")

    if (Test-Path "./.git") {
        Write-Info "Repository ${GIT_USER}/${GIT_REPO} already exists, updating..."
        git config advice.detachedHead false
        git config remote.origin.url "${GIT_HOST}/${GIT_USER}/${GIT_REPO}.git"
        git config remote.origin.fetch "+refs/heads/master:refs/remotes/origin/master"
        git config remote.origin.tapOpt --no-tags

        if (!(git rev-parse -q --verify "${GH_COMMIT}^{commit}")) {
            git fetch origin
        }

        git checkout -f "${GH_REF}" --
        git reset --hard "${GH_REF}" --
        if (Test-Path "./.gitmodules") {
            git submodule foreach --recursive git submodule sync
            git submodule update --init --recursive
        }
    } else {
        git clone "${GIT_HOST}/${GIT_USER}/${GIT_REPO}.git" "$(pwd)"
        git config advice.detachedHead false
        Write-Info "Checking out commit ${GH_REF}..."
        git checkout -f "${GH_REF}" --

        if (Test-Path "./.gitmodules") {
            git submodule foreach --recursive git submodule sync
            git submodule update --init --recursive
        }
    }
}

function GitHub-Fetch {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $GH_USER,
        [Parameter(Mandatory=$true)]
        [String] $GH_REPO,
        [Parameter(Mandatory=$true)]
        [String] $GH_REF
    )
    if ($PSBoundParameters.Count -ne 3) {
        Write-Error "Usage: GitHub-Fetch GITHUB_USER GITHUB_REPOSITORY GITHUB_REF"
        return 1
    }
    #Write-Status "GH_USER: ${GH_USER}"
    #Write-Status "GH_REPO: ${GH_REPO}"
    #Write-Status "GH_REF: ${GH_REF}"
    #Write-Status "GitHub-Fetch"

    Git-Fetch "https://github.com" "${GH_USER}" "${GH_REPO}" "${GH_REF}"
}

function GitLab-Fetch {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $GL_USER,
        [Parameter(Mandatory=$true)]
        [String] $GL_REPO,
        [Parameter(Mandatory=$true)]
        [String] $GL_REF
    )
    if ($PSBoundParameters.Count -ne 3) {
        Write-Error "Usage: GitLab-Fetch GITLAB_USER GITLAB_REPOSITORY GITLAB_REF"
        return 1
    }

    Git-Fetch "https://gitlab.com" "${GL_USER}" "${GL_REPO}" "${GL_REF}"
}

function Apply-Patch {
    Param(
        [Parameter(Mandatory=$true)]
        [String] $COMMIT_URL,
        [Parameter(Mandatory=$true)]
        [String] $COMMIT_HASH
    )

    $PATCH_FILE = Get-Basename "${COMMIT_URL}"

    if ("${COMMIT_URL}".Substring(0, 5) -eq "https") {
        Invoke-WebRequest "${COMMIT_URL}" -OutFile "${PATCH_FILE}"
        if ("${COMMIT_HASH}" -eq $(Get-FileHash ${PATCH_FILE}).Hash) {
            Write-Info "${PATCH_FILE} downloaded successfully and passed hash check"
        } else {
            Write-Error "${PATCH_FILE} downloaded successfully and failed hash check"
            return 1
        }
    } else {
        $PATCH_FILE = "${COMMIT_URL}"
    }

    Write-Info "Applying patch ${PATCH_FILE}"

    if (Test-Path "./.git") {
        git apply "${PATCH_FILE}"
    } else {
        # TODO: patch failed in my tests, hence using git apply above
        patch -g 0 -f -p1 -i "${PATCH_FILE}"
    }
}

function Check-Archs {
    Write-Step "Check Architecture..."

    if ("${BuildArch}" -eq "64-bit") {
        $script:ARCH = "x86_64"
        $script:CMAKE_ARCH = "x64"
        $script:CMAKE_BITNESS = "64"
        $script:CMAKE_INSTALL_DIR = "win64"
    } elseif ("${BuildArch}" -eq "32-bit") {
        $script:ARCH = "x86"
        $script:CMAKE_ARCH = "Win32"
        $script:CMAKE_BITNESS = "32"
        $script:CMAKE_INSTALL_DIR = "win32"
    } else {
        Caught-Error "Unsupported architecture '${BuildArch}' provided"
    }
}

function Check-Curl {
    if (!(Test-CommandExists "curl")) {
        Write-Step "Install curl from chocolatey..."
        Invoke-Expression "choco install -y curl"
    }

    $CURLCMD = "C:\ProgramData\chocolatey\bin\curl.exe"

    if ("${CI}" -or $Quiet) {
        $script:CURLCMD = "${CURLCMD} --silent --show-error --location -O"
    } else {
        $script:CURLCMD = "${CURLCMD} --progress-bar --location --continue-at - -O"
    }
}

function Build-Checks {
    if(!$NoChoco) {
        Install-Windows-Build-Tools
    }
    $PRODUCT_NAME_U = "${ProductName}".ToUpper()
    $script:CI_PRODUCT_VERSION = ${CIWorkflowJobString} | Select-String "[ ]+${PRODUCT_NAME_U}_VERSION: '(.+)'" | ForEach-Object{$_.Matches.Groups[1].Value}
    $script:CI_PRODUCT_HASH = ${CIWorkflowJobString} | Select-String "[ ]+${PRODUCT_NAME_U}_HASH: '(.+)'" | ForEach-Object{$_.Matches.Groups[1].Value}

    #Write-Status "CheckoutDir: ${CheckoutDir}"
    #Write-Status "ProductProject: ${ProductProject}"
    #Write-Status "ProductRepo: ${ProductRepo}"
    #Write-Status "ProductHash: ${ProductHash}"
    #Write-Status "ProductName: ${ProductName}"
    #Write-Status "ProductVersion: ${ProductVersion}"
    #Write-Status "PRODUCT_NAME_U: ${PRODUCT_NAME_U}"
    #Write-Status "CI_PRODUCT_VERSION: ${CI_PRODUCT_VERSION}"
    #Write-Status "CI_PRODUCT_HASH: ${CI_PRODUCT_HASH}"

    Check-Archs
    #Check-Curl

    #Ensure-Directory "${BuildDirectory}\win32"
    #Ensure-Directory "${BuildDirectory}\win32\bin"
    #Ensure-Directory "${BuildDirectory}\win32\cmake"
    #Ensure-Directory "${BuildDirectory}\win32\include"
    #Ensure-Directory "${BuildDirectory}\win64"
    #Ensure-Directory "${BuildDirectory}\win64\bin"
    #Ensure-Directory "${BuildDirectory}\win64\cmake"
    #Ensure-Directory "${BuildDirectory}\win64\include"
}

function Build-Setup {
    Trap { Caught-Error "build-${ProductName}" }

    Ensure-Directory "${CheckoutDir}/windows_build_temp"

    if (!$ProductHash) {
        $ProductHash = $CI_PRODUCT_HASH
    }

    Write-Step "Download..."
    Check-And-Fetch "${ProductUrl}" "${ProductHash}"

    if (!"${SKIP_UNPACK}") {
        Write-Step "Unpack..."
        tar -xf ${ProductFilename}
    }

    cd "${ProductFolder}"
}

function Build-Setup-GitHub {
    Trap { Caught-Error "build-${ProductName}" }

    Ensure-Directory "${CheckoutDir}/windows_build_temp"

    if (!$ProductHash) {
        $ProductHash = $CI_PRODUCT_HASH
    }

    #Write-Status "CheckoutDir: ${CheckoutDir}"
    #Write-Status "ProductProject: ${ProductProject}"
    #Write-Status "ProductRepo: ${ProductRepo}"
    #Write-Status "ProductHash: ${ProductHash}"

    Write-Step "Git checkout..."
    Ensure-Directory "${ProductRepo}"
    GitHub-Fetch ${ProductProject} ${ProductRepo} ${ProductHash}
}

function Build-Setup-GitLab {
    Trap { Caught-Error "build-${ProductName}" }

    Ensure-Directory "${CheckoutDir}/windows_build_temp"

    if (!$ProductHash) {
        $ProductHash = $CI_PRODUCT_HASH
    }

    Write-Step "Git checkout..."
    Ensure-Directory "${ProductRepo}"
    GitLab-Fetch ${ProductProject} ${ProductRepo} ${ProductHash}
}

function Build {
    if (!$ProductVersion) {
        $ProductVersion = $CI_PRODUCT_VERSION
    }

    Write-Status "Build ${ProductName} ${ProductVersion}"

    if (Test-CommandExists 'Patch-Product') {
        Ensure-Directory "${CheckoutDir}/windows_build_temp"
        Patch-Product
    }

    if (Test-CommandExists 'Build-Product') {
        Ensure-Directory "${CheckoutDir}/windows_build_temp"
        Build-Product
    }

    if (Test-CommandExists 'Install-Product') {
        Ensure-Directory "${CheckoutDir}/windows_build_temp"
        Install-Product
    }
}