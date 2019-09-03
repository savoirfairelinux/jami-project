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

$fail_times = 0

iex ("choco install -fy --allow-downgrade wget --version 1.19.4 --acceptlicense")
$fail_times += $LASTEXITCODE
iex ("choco install -fy --allow-downgrade git.install --version 2.10.2 --acceptlicense")
$fail_times += $LASTEXITCODE
iex ("choco install -fy 7zip --acceptlicense")
$fail_times += $LASTEXITCODE
iex ("choco install -fy unzip --acceptlicense")
$fail_times += $LASTEXITCODE
iex ("choco install -fy cmake --acceptlicense")
$fail_times += $LASTEXITCODE
iex ("choco install -fy pandoc --acceptlicense")
$fail_times += $LASTEXITCODE
iex ("choco install -fy strawberryperl --acceptlicense")
$fail_times += $LASTEXITCODE
iex ("choco install -fy msys2 --acceptlicense")

if( $fail_times -eq 0 ) {
    write-host "Choco Packages Installation Succeeded" -ForegroundColor Green
} else {
    write-host "Choco Packages Installation Failed" -ForegroundColor Red
    exit 1
}

# Web installed msys2_64 bit to install make, gcc, perl, diffutils

$fail_times = 0

$Env:Path += ";C:\tools\msys64\usr\bin"
iex ("pacman -S make --noconfirm")
$fail_times += $LASTEXITCODE
iex ("pacman -S gcc --noconfirm")
$fail_times += $LASTEXITCODE
iex ("pacman -S perl --noconfirm")
$fail_times += $LASTEXITCODE
iex ("pacman -S diffutils --noconfirm")
$fail_times += $LASTEXITCODE

if( $fail_times -eq 0 ) {
    write-host "Pacman Packages Installation Succeeded" -ForegroundColor Green
} else {
    write-host "Pacman Packages Installation Failed" -ForegroundColor Red
    exit 1
}

# Web Download VSNASM, VSYASM

write-host "Downloading VSNASM" -ForegroundColor Yellow
$url = "https://github.com/ShiftMediaProject/VSNASM/releases/download/0.5/VSNASM.zip";
$output = $env:TEMP + "\VSNASM.zip"
(New-Object System.Net.WebClient).DownloadFile($url, $output)

if( $LASTEXITCODE -eq 0 ) {
    write-host "Download VSNASM Succeeded" -ForegroundColor Green
} else {
    write-host "Download VSNASM Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

write-host "Downloading VSYASM" -ForegroundColor Yellow
$url = "https://github.com/ShiftMediaProject/VSYASM/releases/download/0.4/VSYASM.zip"
$output = $env:TEMP + "\VSYASM.zip"
(New-Object System.Net.WebClient).DownloadFile($url, $output)

if( $LASTEXITCODE -eq 0 ) {
    write-host "Download VSYASM Succeeded" -ForegroundColor Green
} else {
    write-host "Download VSYASM Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Unzip VSNASM.zip, VSYASM.zip

write-host "Unzip VSNASM" -ForegroundColor Yellow
$zip_path = $env:TEMP + "\VSNASM.zip"
$unzip_path = $env:TEMP + "\VSNASM_UNZIP"
iex("unzip -o '$zip_path' -d '$unzip_path'")

if( $LASTEXITCODE -eq 0 ) {
    write-host "Unzip VSNASM Succeeded" -ForegroundColor Green
} else {
    write-host "Unzip VSNASM Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

write-host "Unzip VSYASM" -ForegroundColor Yellow
$zip_path = $env:TEMP + "\VSYASM.zip"
$unzip_path = $env:TEMP + "\VSYASM_UNZIP"
iex("unzip -o '$zip_path' -d '$unzip_path'")

if( $LASTEXITCODE -eq 0 ) {
    write-host "Unzip VSYASM Succeeded" -ForegroundColor Green
} else {
    write-host "Unzip VSYASM Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Generate nasm(VS), yasm.exe (VS)

write-host "Generating nasm.exe (VS)" -ForegroundColor Yellow
$batch_path = "/c set ISINSTANCE=1 && " + '"' + $env:TEMP + "\VSNASM_UNZIP\install_script.bat" + '"'
Start-Process "cmd.exe" $batch_path -Wait -NoNewWindow

if( $LASTEXITCODE -eq 0 ) {
    write-host "Generate nasm(VS) Succeeded" -ForegroundColor Green
} else {
    write-host "Generate nasm(VS) Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

write-host "Generating yasm.exe (VS)" -ForegroundColor Yellow
$batch_path = "/c set ISINSTANCE=1 &&" + '"' + $env:TEMP + "\VSYASM_UNZIP\install_script.bat" + '"'
Start-Process "cmd.exe" $batch_path -Wait -NoNewWindow

if( $LASTEXITCODE -eq 0 ) {
    write-host "Generate yasm(VS) Succeeded" -ForegroundColor Green
} else {
    write-host "Generate yasm(VS) Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Web Download gas-preprocessor.pl, yasm.exe (win64)

write-host "Downloading yasm.exe (win64)" -ForegroundColor Yellow
$url = "http://www.tortall.net/projects/yasm/releases/yasm-1.3.0-win64.exe"
$output = $env:TEMP + "\yasm.exe"
(New-Object System.Net.WebClient).DownloadFile($url, $output)

if( $LASTEXITCODE -eq 0 ) {
    write-host "Download yasm(win64) Succeeded" -ForegroundColor Green
} else {
    write-host "Download yasm(win64) Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

write-host "Downloading gas-preprocessor.pl" -ForegroundColor Yellow
$url = "https://github.com/FFmpeg/gas-preprocessor/blob/master/gas-preprocessor.pl"
$output = $env:TEMP + "\gas-preprocessor.pl"
(New-Object System.Net.WebClient).DownloadFile($url, $output)

if( $LASTEXITCODE -eq 0 ) {
    write-host "Download gas-preprocessor.pl Succeeded" -ForegroundColor Green
} else {
    write-host "Download gas-preprocessor.pl Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Move gas-preprocessor.pl, yasm.exe into C:\\tools\\msys64\\usr\\bin

write-host "Moving gas-preprocessor.pl to msys64 folder" -ForegroundColor Yellow
$gas_path = $env:TEMP + "\gas-preprocessor.pl"
Move-item -Path $gas_path -Destination "C:\tools\msys64\usr\bin" -Force

if( $LASTEXITCODE -eq 0 ) {
    write-host "Move gas-preprocessor.pl Succeeded" -ForegroundColor Green
} else {
    write-host "Move gas-preprocessor.pl Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

write-host "Moving yasm.exe (win64) to msys64 folder" -ForegroundColor Yellow
$yasm_path = $env:TEMP + "\yasm.exe"
Move-item -Path $yasm_path -Destination "C:\tools\msys64\usr\bin" -Force

if( $LASTEXITCODE -eq 0 ) {
    write-host "Move yasm(win64) Succeeded" -ForegroundColor Green
} else {
    write-host "Move yasm(win64) Failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

write-host "Dependencies Built Finished" -ForegroundColor Green