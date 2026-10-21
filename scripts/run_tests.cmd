@echo off
REM ---------------------------------------------------------------------------
REM Es Cekek — headless test runner (Windows)
REM
REM Usage:
REM   scripts\run_tests.cmd          -> run the runtime smoke test
REM   scripts\run_tests.cmd --boot   -> also boot the game headless for N frames
REM
REM Requires Godot 4.x. Override the binary with the GODOT env var:
REM   set GODOT=C:\path\to\Godot.exe
REM ---------------------------------------------------------------------------
setlocal

if "%GODOT%"=="" set "GODOT=C:\Users\WIN10\AppData\Local\Godot\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%GODOT%" (
    echo [ERROR] Godot binary not found: "%GODOT%"
    echo         Set the GODOT environment variable to your Godot 4 executable.
    exit /b 1
)

set "PROJECT=%~dp0.."

echo === Running runtime smoke test ===
"%GODOT%" --headless --path "%PROJECT%" --script res://tests/runtime_test.gd
set "TEST_RESULT=%ERRORLEVEL%"

if "%~1"=="--boot" (
    echo.
    echo === Booting game headless (120 frames) ===
    "%GODOT%" --headless --quit-after 120 --path "%PROJECT%"
    if %ERRORLEVEL% NEQ 0 (
        echo [FAIL] game boot returned %ERRORLEVEL%
        exit /b %ERRORLEVEL%
    )
    echo [OK] game booted without errors
)

echo.
if %TEST_RESULT% NEQ 0 (
    echo [FAIL] runtime test failed (exit %TEST_RESULT%)
    exit /b %TEST_RESULT%
)
echo [OK] all runtime tests passed
exit /b 0
