@echo off
setlocal EnableDelayedExpansion

if not "%~2"=="" (
  echo [ERROR] Too many arguments.
  echo Usage: %~nx0 ["PROJECT_ROOT_PATH"]
  timeout /t 10 /nobreak >nul
  exit /b 1
)

if "%~1"=="" (
  set "PROJECT_ROOT=%USERPROFILE%"
) else (
  set "PROJECT_ROOT=%~1"
)

set "SOURCE_DIR=%~dp0."
set "TARGET_DIR=%PROJECT_ROOT%\.cursor\plugins\local\r2e"

echo Source: %SOURCE_DIR% ^| Target: %TARGET_DIR%

if not exist "%SOURCE_DIR%\.cursor-plugin\plugin.json" (
  echo [ERROR] Plugin manifest not found: %SOURCE_DIR%\.cursor-plugin\plugin.json
  timeout /t 10 /nobreak >nul
  exit /b 1
)

if exist "%TARGET_DIR%\" (
  echo Removing existing plugin: %TARGET_DIR%
  rmdir /s /q "%TARGET_DIR%"
  if errorlevel 1 (
    echo [ERROR] Failed to remove existing plugin directory.
    timeout /t 10 /nobreak >nul
    exit /b 1
  )
)

if not exist "%SOURCE_DIR%\rules\" (
  echo [ERROR] Required directory not found: %SOURCE_DIR%\rules
  timeout /t 10 /nobreak >nul
  exit /b 1
)

if not exist "%SOURCE_DIR%\skills\" (
  echo [ERROR] Required directory not found: %SOURCE_DIR%\skills
  timeout /t 10 /nobreak >nul
  exit /b 1
)

mkdir "%TARGET_DIR%" >nul 2>&1

call :copy_dir ".cursor-plugin"
if errorlevel 1 exit /b 1

call :copy_dir "rules"
if errorlevel 1 exit /b 1

call :copy_dir "skills"
if errorlevel 1 exit /b 1

echo Plugin installed successfully. Please restart Cursor
timeout /t 10 /nobreak >nul
exit /b 0

:copy_dir
set "COPY_NAME=%~1"
robocopy "%SOURCE_DIR%\%COPY_NAME%" "%TARGET_DIR%\%COPY_NAME%" /e >nul
set "ROBOCOPY_EXIT=%errorlevel%"
if %ROBOCOPY_EXIT% GEQ 8 (
  echo [ERROR] Failed to copy %COPY_NAME%. ^(robocopy exit code: %ROBOCOPY_EXIT%^) 
  timeout /t 10 /nobreak >nul
  exit /b 1
)
exit /b 0
