@echo off
title Build Flutter APK
setlocal

:: Set PUB_CACHE to the same drive as the workspace to avoid Gradle cross-drive issues
set PUB_CACHE=D:\BizPOS_Pub_Cache

:: Navigate to the directory where this batch file is located
pushd "%~dp0"

echo Current directory is: %CD%

:: Verify it's a Flutter project
if not exist "pubspec.yaml" (
    echo ERROR: pubspec.yaml not found in %CD%
    echo Make sure you are running this from the root of the Flutter project.
    pause
    popd
    exit /b 1
)

echo.
echo ========================================================
echo Starting APK Build Process...
echo ========================================================
echo.

set /p CHOICE="Do you want to run a full clean build? (y/n, default: n): "
if /i "%CHOICE%"=="y" (
    echo [1/3] Cleaning project...
    call "C:\src\flutter\bin\flutter.bat" clean
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo ERROR: Flutter clean failed.
        pause
        popd
        exit /b 1
    )

    echo.
    echo [2/3] Getting dependencies...
    call "C:\src\flutter\bin\flutter.bat" pub get
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo ERROR: Flutter pub get failed.
        pause
        popd
        exit /b 1
    )
) else (
    echo [1/2] Skipping clean and pub get for a faster build...
)

echo.
echo [3/3] Building Release APK with obfuscation...
call "C:\src\flutter\bin\flutter.bat" build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: APK build failed. Check the errors above.
    pause
    popd
    exit /b 1
)

echo.
echo ========================================================
echo BUILD SUCCESSFUL!
echo The APK should be located in: build\app\outputs\flutter-apk\app-release.apk
echo ========================================================
echo.

popd
pause
