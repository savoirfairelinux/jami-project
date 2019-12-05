# Install Choco

Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1"))

if( $LASTEXITCODE -eq 0 ) {
    write-host "Choco Installation Succeeded" -ForegroundColor Green
} else {
    write-host "Choco Installation Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Install 7zip, unzip, wget --version 1.19.4, cmake, git --version 2.10.2
# pandoc, strawberryperl, msys2
# Note that: msys2 installes at C:/tools/msys64

Function choco_pack_install($packages) {

    Foreach ($i in $packages){
        if($i -eq 'wget'){
            iex ("choco install -fy --allow-downgrade '$i' --version 1.19.4 --acceptlicense")
        } elseif ($i -eq 'git.install') {
            iex ("choco install -fy --allow-downgrade '$i' --version 2.10.2 --acceptlicense")
        } else {
            iex ("choco install -fy '$i' --acceptlicense")
        }
        if( $LASTEXITCODE -ne 0 ) {
            write-host "Choco Packages Installation Failed" -ForegroundColor Red
            exit 1
        }
    }
    write-host "Choco Packages Installation Succeeded" -ForegroundColor Green
}

$packages = [System.Collections.Generic.List[System.Object]]('wget', 'git.install', '7zip', 'unzip', 'cmake', 'pandoc', 'strawberryperl', 'msys2')

if(Test-Path -Path "C:\Program Files\CMake\bin"){
    # file with path $path does exist
    $null = $packages.Remove('cmake')
    write-host "Cmake installed" -ForegroundColor Green
}

if(Test-Path -Path "C:\Strawberry"){
    $null = $packages.Remove('strawberryperl')
    write-host "Strawberry Perl installed" -ForegroundColor Green
}

if(!(Test-Path -Path "C:\msys64")){
    $Env:Path += ";C:\tools\msys64\usr\bin"
    $msys2_path = "C:\tools\msys64\usr\bin"
    if((Test-Path -Path "C:\tools\msys64")){
        $null = $packages.Remove('msys2')
        write-host "MSYS2 64 installed" -ForegroundColor Green
    }
} else {
    $null = $packages.Remove('msys2')
    write-host "MSYS2 64 installed" -ForegroundColor Green
    $Env:Path += ";C:\msys64\usr\bin"
    $msys2_path = "C:\msys64\usr\bin"
}

choco_pack_install($packages)

# Web installed msys2_64 bit to install make, gcc, perl, diffutils

Function pacman_pack_install($packages) {

    Foreach ($i in $packages){
        iex ("pacman -S '$i' --noconfirm")
        if( $LASTEXITCODE -ne 0 ) {
            write-host "Pacman Packages Installation Failed" -ForegroundColor Red
            exit 1
        }
    }
    write-host "Pacman Packages Installation Succeeded" -ForegroundColor Green
}

$packages = [System.Collections.Generic.List[System.Object]]('make', 'gcc', 'perl', 'diffutils')

pacman_pack_install($packages)

# Web Download VSNASM, VSYASM

Function download_file_to_temp($download_name, $url, $output_name) {

    write-host "Downloading $download_name" -ForegroundColor Yellow
    $output = $env:TEMP + "\$output_name"
    (New-Object System.Net.WebClient).DownloadFile($url, $output)

    if( $LASTEXITCODE -eq 0 ) {
        write-host "Download $download_name Succeeded" -ForegroundColor Green
    } else {
        write-host "Download $download_name Failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

download_file_to_temp 'VSNASM' "https://github.com/ShiftMediaProject/VSNASM/releases/download/0.5/VSNASM.zip" 'VSNASM.zip'
download_file_to_temp 'VSYASM' "https://github.com/ShiftMediaProject/VSYASM/releases/download/0.4/VSYASM.zip" 'VSYASM.zip'

# Unzip VSNASM.zip, VSYASM.zip

Function unzip_file_from_temp($unzip_name, $zip_file_name, $unzip_file_output_name) {

    write-host "Unzip $unzip_name" -ForegroundColor Yellow
    $zip_path = $env:TEMP + "\$zip_file_name"
    $unzip_path = $env:TEMP + "\$unzip_file_output_name"
    iex("unzip -o $zip_path -d $unzip_path")

    if( $LASTEXITCODE -eq 0 ) {
        write-host "Unzip $unzip_name Succeeded" -ForegroundColor Green
    } else {
        write-host "Unzip $unzip_name Failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

unzip_file_from_temp 'VSNASM' 'VSNASM.zip' 'VSNASM_UNZIP'
unzip_file_from_temp 'VSYASM' 'VSYASM.zip' 'VSYASM_UNZIP'

# Generate nasm(VS), yasm.exe (VS)

Function run_batch($batch_cmd, $task_desp) {

    write-host $task_desp -ForegroundColor Yellow
    Start-Process "cmd.exe" $batch_cmd -Wait -NoNewWindow

    if( $LASTEXITCODE -eq 0 ) {
        write-host "$task_desp Succeeded" -ForegroundColor Green
    } else {
        write-host "$task_desp Failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

$batch_path = "/c set ISINSTANCE=1 && " + $env:TEMP + "\VSNASM_UNZIP\install_script.bat"
run_batch $batch_path "Generate nasm(VS)"

$batch_path = "/c set ISINSTANCE=1 &&" + $env:TEMP + "\VSYASM_UNZIP\install_script.bat"
run_batch $batch_path "Generate yasm(VS)"

# Web Download gas-preprocessor.pl, yasm.exe (win64)

download_file_to_temp 'yasm.exe (win64)' "http://www.tortall.net/projects/yasm/releases/yasm-1.3.0-win64.exe" 'yasm.exe'
download_file_to_temp 'gas-preprocessor.pl' "https://github.com/FFmpeg/gas-preprocessor/blob/master/gas-preprocessor.pl" 'gas-preprocessor.pl'

# Move gas-preprocessor.pl, yasm.exe into msys64

Function move_file_from_temp_to_msys64($file_name, $task_desp) {

    write-host $task_desp -ForegroundColor Yellow
    $file_path = $env:TEMP + "\$file_name"
    Move-item -Path $file_path -Destination $msys2_path -Force

    if( $LASTEXITCODE -eq 0 ) {
        write-host "$task_desp Succeeded" -ForegroundColor Green
    } else {
        write-host "$task_desp Failed" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

move_file_from_temp_to_msys64 'gas-preprocessor.pl' 'Move gas-preprocessor.pl to msys64 folder'
move_file_from_temp_to_msys64 'yasm.exe' 'Move yasm.exe (win64) to msys64 folder'

write-host "Dependencies Built Finished" -ForegroundColor Green