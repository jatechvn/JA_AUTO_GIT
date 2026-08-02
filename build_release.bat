@echo off
setlocal enabledelayedexpansion
title Build JA Auto Git - Release Packager

echo =======================================================================
echo                 JA AUTO GIT - BUILD AND PACKAGER
echo =======================================================================
echo.

set WORKSPACE_DIR=%~dp0
cd /d "%WORKSPACE_DIR%"

:: Read app version from pubspec.yaml so release naming never drifts out of sync
for /f "tokens=2 delims= " %%v in ('findstr /b "version:" pubspec.yaml') do set PUBSPEC_VERSION=%%v
for /f "tokens=1 delims=+" %%v in ("%PUBSPEC_VERSION%") do set APP_VERSION=%%v
echo Detected app version: v%APP_VERSION%
echo.

:: 0. Kill running instances of the app
echo [0/5] Terminating any active ja_auto_git.exe instances...
taskkill /IM ja_auto_git.exe /F 2>nul
timeout /t 1 /nobreak >nul
echo.

:: 1. Clean up old dist folder
echo [1/5] Clearing previous distribution folder...
if exist "dist" (
    rmdir /s /q "dist"
)
mkdir "dist"
echo.

:: 2. Build Windows App
echo [2/5] Compiling Windows application (Release mode)...
call flutter build windows --release

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Flutter build failed!
    pause
    exit /b %ERRORLEVEL%
)

set RELEASE_DIR=build\windows\x64\runner\Release

echo.
:: 3. Copy bin, assets, and documentation to build output
echo [3/5] Bundling embedded binaries (bin\), assets, and docs to build output...
if exist "bin" (
    echo Copying bin/ ^(gh.exe, git/^) ...
    xcopy /e /i /y /q "bin" "%RELEASE_DIR%\bin\"
)
if exist "assets" (
    echo Copying assets/...
    xcopy /e /i /y /q "assets" "%RELEASE_DIR%\assets\"
)
if exist "i18n" (
    echo Copying i18n/...
    xcopy /e /i /y /q "i18n" "%RELEASE_DIR%\i18n\"
)
if exist "ABOUT.txt" copy /y "ABOUT.txt" "%RELEASE_DIR%\" >nul
if exist "README.md" copy /y "README.md" "%RELEASE_DIR%\" >nul
if exist "CHANGELOG.md" copy /y "CHANGELOG.md" "%RELEASE_DIR%\" >nul
if exist "LICENSE" copy /y "LICENSE" "%RELEASE_DIR%\" >nul
if exist "debug.bat" copy /y "debug.bat" "%RELEASE_DIR%\" >nul

echo.
:: 4. Copy fully self-contained release to dist/
echo [4/5] Copying complete self-contained release to dist/...
xcopy /e /i /y /q "%RELEASE_DIR%\*.*" "dist\"

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Failed to copy release files to dist/
    pause
    exit /b %ERRORLEVEL%
)

echo.
:: 5. Create ZIP package wrapped in Parent Folder inside
echo [5/5] Packaging standalone ZIP release wrapped in parent folder...
if exist "dist_pack" rmdir /s /q "dist_pack"
mkdir "dist_pack\JA_Auto_Git_v%APP_VERSION%_Windows_x64"
xcopy /e /i /y /q "dist\*.*" "dist_pack\JA_Auto_Git_v%APP_VERSION%_Windows_x64\"
powershell -Command "Compress-Archive -Path 'dist_pack\*' -DestinationPath 'dist\JA_Auto_Git_v%APP_VERSION%_Windows_x64.zip' -Force"
if exist "dist_pack" rmdir /s /q "dist_pack"

echo.
:: 6. Generate Release Notes for GitHub
echo [6/6] Generating Release Notes...
powershell -Command "$text = Get-Content CHANGELOG.md -Raw; $regex = '(?s)## \[v%APP_VERSION%\].*?(?=## \[v)'; if ($text -match $regex) { Set-Content -Path 'dist\RELEASE_NOTES.md' -Value ('TAG=v%APP_VERSION%' + [Environment]::NewLine + 'TITLE=Release v%APP_VERSION%' + [Environment]::NewLine + 'BODY=' + [Environment]::NewLine + $matches[0]) } else { Set-Content -Path 'dist\RELEASE_NOTES.md' -Value ('TAG=v%APP_VERSION%' + [Environment]::NewLine + 'TITLE=Release v%APP_VERSION%') }"

echo.
echo =======================================================================
echo  BUILD COMPLETED SUCCESSFULLY!
echo =======================================================================
echo.
echo The self-contained application with bin, assets ^& docs is ready in:
echo %WORKSPACE_DIR%dist\
echo.
echo Standalone parent-folder ZIP package:
echo %WORKSPACE_DIR%dist\JA_Auto_Git_v%APP_VERSION%_Windows_x64.zip
echo Release Notes:
echo %WORKSPACE_DIR%dist\RELEASE_NOTES.md
echo.
pause

