@echo off
setlocal

cd /d "%~dp0"

if not exist "lib\" (
    echo Khong tim thay thu muc lib.
    pause
    exit /b 1
)

if exist "lib.zip" del /f /q "lib.zip"

powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path 'lib' -DestinationPath 'lib.zip' -Force"

echo Da dong goi xong: %cd%\lib.zip
pause
