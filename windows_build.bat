@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM  windows_build.bat
REM  Builds Timer Counter for Windows release.
REM ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%" >nul

set "APP_NAME=Timer Counter"
set "APP_EXE=timer_counter.exe"
set "BUILD_DIR=build\windows\x64\runner\Release"
set "SHOULD_PAUSE=1"
if defined NONINTERACTIVE_BUILD set "SHOULD_PAUSE="

call :read_version
if errorlevel 1 goto :fail

echo.
echo ============================================
echo  Building %APP_NAME% for Windows
echo  Version: !APP_VERSION! ^(raw: !RAW_VERSION!^)
echo ============================================

call :require_command flutter
if errorlevel 1 goto :fail
call :require_command dart
if errorlevel 1 goto :fail

if not exist "assets\icons\app_icon.ico" (
    if exist "windows\runner\resources\app_icon.ico" (
        echo Copying Windows icon to assets\icons\app_icon.ico ...
        copy /Y "windows\runner\resources\app_icon.ico" "assets\icons\app_icon.ico" >nul
    ) else (
        echo [ERROR] Missing icon: assets\icons\app_icon.ico
        goto :fail
    )
)

call :ensure_app_not_running
if errorlevel 1 goto :fail

echo Running "flutter clean"...
call flutter clean
if errorlevel 1 goto :fail

echo Running "flutter pub get"...
call flutter pub get
if !errorlevel! neq 0 (
    echo First pub get failed. Cleaning Flutter ephemeral plugin links and retrying...
    if exist "windows\flutter\ephemeral\.plugin_symlinks" rmdir /S /Q "windows\flutter\ephemeral\.plugin_symlinks"
    if exist "windows\flutter\ephemeral" attrib -R "windows\flutter\ephemeral" /S /D
    if exist "windows\flutter" attrib -R "windows\flutter" /S /D
    call flutter pub get
    if !errorlevel! neq 0 goto :fail
)

echo Running "flutter build windows --release"...
call flutter build windows --release
if errorlevel 1 goto :fail

if not exist "%BUILD_DIR%\%APP_EXE%" (
    echo [ERROR] Expected build output missing: %BUILD_DIR%\%APP_EXE%
    goto :fail
)

echo.
echo [OK] Windows release build created:
echo      %BUILD_DIR%\%APP_EXE%
goto :success

:read_version
set "RAW_VERSION="
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "(Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()"`) do set "RAW_VERSION=%%V"
if not defined RAW_VERSION (
    echo [ERROR] Could not read version from pubspec.yaml.
    exit /b 1
)
for /f "tokens=1 delims=+" %%V in ("!RAW_VERSION!") do set "APP_VERSION=%%V"
exit /b 0

:require_command
where %~1 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Required command not found on PATH: %~1
    exit /b 1
)
exit /b 0

:ensure_app_not_running
tasklist /FI "IMAGENAME eq %APP_EXE%" 2>NUL | find /I "%APP_EXE%" >NUL
if errorlevel 1 exit /b 0

echo %APP_NAME% is currently running and may lock the build directory.
if defined NONINTERACTIVE_BUILD (
    echo Stopping %APP_EXE% for non-interactive build...
    taskkill /F /IM "%APP_EXE%" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Failed to stop %APP_EXE%.
        exit /b 1
    )
    exit /b 0
)

set "STOP_CHOICE="
set /p STOP_CHOICE=Stop running %APP_NAME% now? [y/N]: 
if /i not "!STOP_CHOICE!"=="Y" (
    echo [ERROR] Build cancelled because %APP_NAME% is still running.
    exit /b 1
)
taskkill /F /IM "%APP_EXE%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to stop %APP_EXE%.
    exit /b 1
)
exit /b 0

:success
popd >nul
if defined SHOULD_PAUSE pause
endlocal
exit /b 0

:fail
set "EXIT_CODE=%errorlevel%"
if "%EXIT_CODE%"=="0" set "EXIT_CODE=1"
echo.
echo [FAIL] Windows build failed.
popd >nul
if defined SHOULD_PAUSE pause
endlocal
exit /b %EXIT_CODE%