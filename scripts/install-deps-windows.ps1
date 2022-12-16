<#
    This script should install dependencies required for building the Jami
    Qt client on windows.

    Required components not installed:
    - Visual Studio
    - build toolchains
    - SDKs
    - WiX + WiX Visual Studio extension
    - Qt + Qt Visual Studio extension
#>

write-host "Installing jami-qt build dependencies for windows…" -ForegroundColor Green

Set-ExecutionPolicy Bypass -Scope Process -Force

$global:installed_packages = $null
Function choco_check_package([String] $package, [String] $version = "") {
    # Query a package listing once
    if ($null -eq $global:installed_packages) {
        write-host "Getting installed package list from Chocolatey…" -ForegroundColor DarkCyan
        $global:installed_packages = choco list -lo
    }
    # Check installed packages
    $result = $global:installed_packages | Where-object {
        $_.ToLower().StartsWith($package.ToLower())
    }
    if ($null -eq $result) {
        # We don't have the package
        write-host $package "not found." -ForegroundColor Yellow
        return $false
    }
    if ("" -eq $version) {
        # We have the package and don't care what version it is
        write-host $package "found." -ForegroundColor Cyan
        return $true
    }
    # We now check the results for a package of the specified version
    $parts = $result.Split(' ')
    Foreach ($part in $parts) {
        if ($part -eq $version) {
            # We have the package of the specified version
            write-host $package $version "found." -ForegroundColor Cyan
            return $true
        }
    }
    # We don't have the package of the specified version
    write-host $package $version "not found." -ForegroundColor Yellow
    return $false
}

Function install_chocolatey {
    # Install Chocolatey if not installed already
    if (!(Test-Path "$($env:ProgramData)\chocolatey\choco.exe")) {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1"))
        if ( $LASTEXITCODE -eq 0 ) {
            write-host "Chocolatey installation succeeded" -ForegroundColor Green
        }
        else {
            write-host "Chocolatey installation failed" -ForegroundColor Red
            exit $LASTEXITCODE
        }
    }
    else {
        write-host "Chocolatey already installed" -ForegroundColor DarkGreen
    }
}

Function choco_install_package([String] $package, [String] $version = "") {
    $package_installed = choco_check_package $package $version
    if ($true -eq $package_installed) {
        return
    }
    if ("" -ne $version) {
        write-host "Installing" $package "@" $version
        choco install -fy --allow-downgrade $package --version $version --acceptlicense
    }
    else {
        write-host "Installing" $package
        choco install -fy --allow-downgrade $package --acceptlicense
    }
    if ( $LASTEXITCODE -ne 0 ) {
        write-host "Choco Packages Installation Failed" -ForegroundColor Red
        exit 1
    }
}
Function install_choco_packages($packages) {
    Foreach ($i in $packages) {
        choco_install_package $i.pkg $i.ver
    }
    write-host "Choco Packages Installation Succeeded" -ForegroundColor Green
}

Function download_file_to_temp($download_name, $url, $output_name) {
    write-host "Downloading $download_name" -ForegroundColor DarkCyan
    $output = $env:TEMP + "\$output_name"
    (New-Object System.Net.WebClient).DownloadFile($url, $output)
    if ( $LASTEXITCODE -eq 0 ) {
        write-host "Download $download_name Succeeded" -ForegroundColor Green
    }
    else {
        write-host "Download $download_name Failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Function unzip_file_from_temp($unzip_name, $zip_file_name, $unzip_file_output_name) {
    write-host "Unzipping $unzip_name" -ForegroundColor DarkCyan
    $zip_path = $env:TEMP + "\$zip_file_name"
    $unzip_path = $env:TEMP + "\$unzip_file_output_name"
    Invoke-Expression("unzip -o $zip_path -d '$unzip_path'") | Out-Null
    if ( $LASTEXITCODE -eq 0 ) {
        write-host "Unzip $unzip_name Succeeded" -ForegroundColor Green
    }
    else {
        write-host "Unzip $unzip_name Failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Function run_batch($batch_cmd, $task_name) {
    write-host $task_name -ForegroundColor DarkCyan
    Start-Process "cmd.exe" $batch_cmd -Wait -NoNewWindow | Out-Null
    if ( $LASTEXITCODE -eq 0 ) {
        write-host "$task_name Succeeded" -ForegroundColor Green
    }
    else {
        write-host "$task_name Failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Function move_file_from_temp_to_msys64($file_name, $task_name) {
    write-host $task_name -ForegroundColor DarkCyan
    $file_path = $env:TEMP + "\$file_name"
    Move-item -Path $file_path -Destination $msys2_path -Force
    if ($LASTEXITCODE -eq 0) {
        write-host "$task_name Succeeded" -ForegroundColor Green
    }
    else {
        write-host "$task_name Failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Function install_msys2_packages($packages) {
    Foreach ($i in $packages) {
        Invoke-Expression ("pacman -Q '$i'") | out-null
        if ($LASTEXITCODE -eq 0) {
            write-host $i "already installed" -ForegroundColor Cyan
            continue
        }
        Invoke-Expression ("pacman -S '$i' --noconfirm")
        if ($LASTEXITCODE -ne 0) {
            write-host "Pacman Packages Installation Failed" -ForegroundColor Red
            exit 1
        }
    }
    write-host "Pacman Packages Installation Succeeded" -ForegroundColor Green
}

# Web installed msys2_64 bit to install make, gcc, perl, diffutils
$msys_packages = @("make", "gcc", "perl", "diffutils")

# Install 7zip, unzip, wget --version 1.19.4, cmake, git --version 2.10.2, pandoc, strawberryperl, msys2
$choco_packages = @(
    [pscustomobject]@{pkg = "wget"; ver = "1.19.4" }
    [pscustomobject]@{pkg = "git.install"; ver = "2.10.2" }
    [pscustomobject]@{pkg = "7zip"; ver = "" }
    [pscustomobject]@{pkg = "unzip"; ver = "" }
    [pscustomobject]@{pkg = "cmake"; ver = "" }
    [pscustomobject]@{pkg = "pandoc"; ver = "" }
    [pscustomobject]@{pkg = "strawberryperl"; ver = "" }
    [pscustomobject]@{pkg = "msys2"; ver = "" }
)

install_chocolatey

# Check for an existing msys2 install
# Note that choco installs msys2 in C:/tools/
if (!(Test-Path -Path "C:\msys64")) {
    $Env:Path += ";C:\tools\msys64\usr\bin"
    $msys2_path = "C:\tools\msys64\usr\bin"
    if ((Test-Path -Path "C:\tools\msys64")) {
        write-host "MSYS2 64 already installed" -ForegroundColor Green
    }
    else {
        $choco_packages.Add([pscustomobject]@{pkg = "msys2"; ver = "" })
    }
}
else {
    write-host "MSYS2 64 already installed" -ForegroundColor Green
    $Env:Path += ";C:\msys64\usr\bin"
    $msys2_path = "C:\msys64\usr\bin"
}

install_choco_packages $choco_packages
install_msys2_packages $msys_packages

# Install VSNASM
download_file_to_temp 'VSNASM' "https://github.com/ShiftMediaProject/VSNASM/releases/download/0.8/VSNASM.zip" 'VSNASM.zip'
unzip_file_from_temp 'VSNASM' 'VSNASM.zip' 'VSNASM_UNZIP'
$batch_path = "/c set ISINSTANCE=1 &&" + $env:TEMP + "\VSNASM_UNZIP\install_script.bat"
run_batch $batch_path "Install VSNASM"

# Install VSYASM
download_file_to_temp 'VSYASM' "https://github.com/ShiftMediaProject/VSYASM/releases/download/0.7/VSYASM.zip" 'VSYASM.zip'
unzip_file_from_temp 'VSYASM' 'VSYASM.zip' 'VSYASM_UNZIP'
$batch_path = "/c set ISINSTANCE=1 &&" + $env:TEMP + "\VSYASM_UNZIP\install_script.bat"
run_batch $batch_path "Install VSYASM"

# Install yasm.exe (win64)
download_file_to_temp 'yasm.exe (win64)' "http://www.tortall.net/projects/yasm/releases/yasm-1.3.0-win64.exe" 'yasm.exe'
move_file_from_temp_to_msys64 'yasm.exe' 'Move yasm.exe (win64) to msys64 folder'

# Install gas-preprocessor.pl
download_file_to_temp 'gas-preprocessor.pl' "https://github.com/FFmpeg/gas-preprocessor/blob/master/gas-preprocessor.pl" 'gas-preprocessor.pl'
move_file_from_temp_to_msys64 'gas-preprocessor.pl' 'Move gas-preprocessor.pl to msys64 folder'

write-host "Done" -ForegroundColor Green
