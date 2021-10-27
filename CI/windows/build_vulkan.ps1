Param(
    [Switch]$Help = $(if (Test-Path variable:Help) { $Help }),
    [Switch]$Quiet = $(if (Test-Path variable:Quiet) { $Quiet }),
    [Switch]$Verbose = $(if (Test-Path variable:Verbose) { $Verbose }),
    [Switch]$NoChoco = $(if (Test-Path variable:NoChoco) { $NoChoco }),
    [Switch]$SkipDependencyChecks = $(if (Test-Path variable:SkipDependencyChecks) { $SkipDependencyChecks }),
    [Switch]$Install = $(if (Test-Path variable:Install) { $Install }),
    [String]$BuildDirectory = "build",
    [ValidateSet("32-bit", "64-bit")]
    [String]$BuildArch = (Get-CimInstance CIM_OperatingSystem).OSArchitecture,
    [ValidateSet("Release", "RelWithDebInfo", "MinSizeRel", "Debug")]
    [String]$BuildConfiguration = "RelWithDebInfo"
)

################################################################################
# Windows Vulkan native-compile build script
################################################################################
#
# This script file can be included in build scripts for Windows or run directly
#
################################################################################

function Build-Product {
    cd "${DepsBuildDir}"

    Write-Step "Download (${ARCH})..."
    $VulkanDownloadUrl = "https://sdk.lunarg.com/sdk/download/${ProductVersion}/windows/VulkanSDK-${ProductVersion}-Installer.exe"
    Write-Output "VulkanDownloadUrl: ${VulkanDownloadUrl}"
    $VulkanDownloadFile = Get-Basename "${VulkanDownloadUrl}"
    Write-Output "ProductVersion: ${ProductVersion}"
    #Invoke-WebRequest -Uri "${VulkanDownloadUrl}" -UseBasicParsing -OutFile "${VulkanDownloadFile}"
}

function Install-Product {
    cd "${DepsBuildDir}"

    Write-Step "Install (${ARCH})..."
    #7z x .\VulkanSDK-1.2.131.2-Installer.exe -ovulkan "include\vulkan" -r "Lib\vulkan-1.lib"
}

function Build-Vulkan-Main {
    $ProductName = "${ProductName}"
    if (!${ProductName}) {
        $ProductName = "vulkan"
    }

    if (!${_RunObsDepsBuildScript}) {
        $CheckoutDir = "$(git rev-parse --show-toplevel)"
        . "${CheckoutDir}/CI/include/build_support_windows.ps1"

        Build-Checks
    }

    Write-Status "ProductName: ${ProductName}"
    Write-Status "ProductVersion: ${ProductVersion}"
    Write-Status "ProductHash: ${ProductHash}"
    Write-Status "ProductUrl: ${ProductUrl}"

    if (!${ProductVersion}) {
        $ProductVersion = $script:CI_PRODUCT_VERSION
    }
    if (!${ProductHash}) {
        $ProductHash = $script:CI_PRODUCT_HASH
    }

    $ProductUrl = "https://sdk.lunarg.com/sdk/download/${ProductVersion}/windows/VulkanSDK-${ProductVersion}-Installer.exe"

    Write-Status "ProductName: ${ProductName}"
    Write-Status "ProductVersion: ${ProductVersion}"
    Write-Status "ProductHash: ${ProductHash}"
    Write-Status "ProductUrl: ${ProductUrl}"

    if (!$Install) {
        Build-Setup
        Build
    } else {
        Install-Product
    }
}

Build-Vulkan-Main
