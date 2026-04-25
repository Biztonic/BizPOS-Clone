@echo off
title FlutterApp-Chrome

:: Navigate to the directory where this batch file is located
pushd "%~dp0"

echo Current directory is: %CD%

if not exist "pubspec.yaml" (
    echo ERROR: pubspec.yaml not found in %CD%
    echo Make sure you are running this from the root of the Flutter project.
    pause
    popd
    exit /b 1
)

echo Starting the application in Chrome (Optimized Mode)...
call "C:\src\flutter\bin\flutter.bat" run -d chrome --release

popd
pause
