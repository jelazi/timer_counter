@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM  deploy_windows.bat
REM  Builds Timer Counter and creates a Windows installer with Inno Setup.
REM
REM  Required tools:
REM    - flutter, dart
REM    - ISCC.exe (Inno Setup 6 compiler)
REM    - powershell
REM ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%" >nul

set "APP_NAME=Timer Counter"
set "APP_EXE=timer_counter.exe"
set "BUILD_SCRIPT=windows_build.bat"
set "ISS_FILE=inno_setup.iss"
set "INNO_OUTPUT_DIR=Output"
set "DEPLOY_OUT_ROOT=deploy\output\windows"
set "SETUP_PREFIX=setup-Timer-Counter"
set "RESULT=NOT_RUN"
set "DETAIL="
set "STAGED_INSTALLER="
set "STAGED_ZIP="
set "SHOULD_PAUSE=1"
if defined NONINTERACTIVE_DEPLOY set "SHOULD_PAUSE="

call :read_version
if errorlevel 1 goto :final_pause

call :detect_iscc
if errorlevel 1 (
    call :record_failure "Inno Setup compiler (ISCC.exe) not found."
    call :log_info  "Install Inno Setup 6 from https://jrsoftware.org/isinfo.php or add ISCC.exe to PATH."
    goto :summary
)

if not exist "%BUILD_SCRIPT%" (
    call :record_failure "Build script missing: %BUILD_SCRIPT%"
    goto :summary
)
if not exist "%ISS_FILE%" (
    call :record_failure "Inno Setup script missing: %ISS_FILE%"
    goto :summary
)

echo.
echo ============================================
echo  Timer Counter Windows deploy
echo  Version: !APP_VERSION! ^(raw: !RAW_VERSION!^)
echo ============================================

call :log_step "Building Windows release via %BUILD_SCRIPT% ..."
set "NONINTERACTIVE_BUILD=1"
call "%BUILD_SCRIPT%"
set "NONINTERACTIVE_BUILD="
if errorlevel 1 (
    call :record_failure "Build script failed: %BUILD_SCRIPT%"
    goto :summary
)

set "BUILD_EXE=build\windows\x64\runner\Release\%APP_EXE%"
if not exist "!BUILD_EXE!" (
    call :record_failure "Expected build output missing: !BUILD_EXE!"
    goto :summary
)

if not exist "%INNO_OUTPUT_DIR%" mkdir "%INNO_OUTPUT_DIR%" >nul 2>&1
set "INSTALLER_EXE=%INNO_OUTPUT_DIR%\%SETUP_PREFIX%-!APP_VERSION!.exe"
if exist "!INSTALLER_EXE!" del /F /Q "!INSTALLER_EXE!" >nul 2>&1

call :log_step "Compiling installer with Inno Setup ..."
"!ISCC_EXE!" "/DMyAppVersion=!APP_VERSION!" "%ISS_FILE%"
set "ISCC_EXIT=!errorlevel!"
if not "!ISCC_EXIT!"=="0" (
    call :record_failure "Inno Setup compilation failed (ISCC exit !ISCC_EXIT!)"
    goto :summary
)
if not exist "!INSTALLER_EXE!" (
    call :record_failure "Installer not produced at expected path: !INSTALLER_EXE!"
    goto :summary
)

set "TIMESTAMP="
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set "TIMESTAMP=%%T"
if not defined TIMESTAMP set "TIMESTAMP=manual_!RANDOM!"
set "STAGE_DIR=%DEPLOY_OUT_ROOT%\!TIMESTAMP!"
mkdir "!STAGE_DIR!" >nul 2>&1
if not exist "!STAGE_DIR!" (
    call :record_failure "Failed to create stage dir: !STAGE_DIR!"
    goto :summary
)

set "STAGED_INSTALLER=!STAGE_DIR!\%SETUP_PREFIX%-!APP_VERSION!.exe"
copy /Y "!INSTALLER_EXE!" "!STAGED_INSTALLER!" >nul
if errorlevel 1 (
    call :record_failure "Failed to copy installer to stage dir"
    goto :summary
)

set "STAGED_ZIP=!STAGE_DIR!\%SETUP_PREFIX%-!APP_VERSION!.zip"
call :log_step "Creating ZIP: !STAGED_ZIP!"
powershell -NoProfile -Command "Compress-Archive -Force -Path '%CD%\!STAGED_INSTALLER!' -DestinationPath '%CD%\!STAGED_ZIP!'"
if errorlevel 1 (
    call :record_failure "ZIP creation failed"
    goto :summary
)

set "RESULT=OK"
set "DETAIL=!STAGED_ZIP!"
call :log_step "Revealing staged installer in Explorer ..."
start "" explorer.exe /select,"%CD%\!STAGED_INSTALLER!"

:summary
echo.
echo ============================================
echo  Windows deploy summary
echo ============================================
if /i "!RESULT!"=="OK" (
    echo  [OK]   Installer: !STAGED_INSTALLER!
    echo  [OK]   ZIP:       !STAGED_ZIP!
) else (
    echo  [FAIL] !DETAIL!
)
echo ============================================

if /i "!RESULT!"=="OK" call :offer_install
goto :final_pause

:log_step
echo [%time:~0,8%] %~1
exit /b 0

:log_info
echo [INFO ] %~1
exit /b 0

:log_error
echo [ERROR] %~1
exit /b 0

:record_failure
set "RESULT=FAIL"
set "DETAIL=%~1"
call :log_error "%~1"
exit /b 0

:read_version
set "RAW_VERSION="
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "(Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()"`) do set "RAW_VERSION=%%V"
if not defined RAW_VERSION (
    call :log_error "Could not read version from pubspec.yaml."
    exit /b 1
)
for /f "tokens=1 delims=+" %%V in ("!RAW_VERSION!") do set "APP_VERSION=%%V"
exit /b 0

:detect_iscc
set "ISCC_EXE="
where ISCC.exe >nul 2>&1
if %errorlevel%==0 (
    for /f "delims=" %%I in ('where ISCC.exe') do if not defined ISCC_EXE set "ISCC_EXE=%%I"
    call :log_info "ISCC found on PATH: !ISCC_EXE!"
    exit /b 0
)
for %%P in (
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles(x86)%\Inno Setup 5\ISCC.exe"
    "%ProgramFiles%\Inno Setup 5\ISCC.exe"
) do (
    if exist %%~P (
        set "ISCC_EXE=%%~P"
        call :log_info "ISCC found at: !ISCC_EXE!"
        exit /b 0
    )
)
exit /b 1

:offer_install
if defined NONINTERACTIVE_DEPLOY (
    set "RESULT=OK"
    exit /b 0
)
set "INSTALL_CHOICE="
set /p INSTALL_CHOICE=Launch installer now? [y/N]: 
if /i "!INSTALL_CHOICE!"=="Y" (
    start "" "!STAGED_INSTALLER!"
)
set "RESULT=OK"
exit /b 0

:final_pause
popd >nul
echo.
if defined SHOULD_PAUSE pause
endlocal
if /i "%RESULT%"=="FAIL" exit /b 1
exit /b 0