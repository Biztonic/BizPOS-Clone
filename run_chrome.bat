@echo off
pushd "%~dp0"

set FLUTTER_BIN=C:\src\flutter\bin\flutter.bat

if not exist "%FLUTTER_BIN%" (
    echo Error: Flutter binary not found at %FLUTTER_BIN%
    pause
    popd
    exit /b 1
)

echo Starting BizPOS in Chrome...
call "%FLUTTER_BIN%" run -d chrome --web-port 8080

popd
pause
