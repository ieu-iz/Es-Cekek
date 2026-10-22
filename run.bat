@echo off
REM ============================================================================
REM  Es Cekek - run.bat (Windows)
REM
REM  Jalankan game LANGSUNG dari source code - tanpa perlu export/build.
REM  Cukup klik ganda file ini, game langsung jalan dari folder project ini.
REM
REM  Pemakaian:
REM    run.bat                  -> main game (res://src/Main.tscn)
REM    run.bat --editor         -> buka Godot Editor
REM    run.bat --test            -> smoke test + boot check (headless)
REM    run.bat --build           -> export 4 platform sekaligus
REM    run.bat --headless        -> game tanpa jendela
REM    run.bat --help            -> tampil bantuan ini
REM    run.bat -- <args Godot>   -> argumen tambahan diteruskan ke Godot
REM
REM  Binary Godot dicari otomatis di %LOCALAPPDATA%\Godot\
REM  Override dengan env var GODOT:
REM    set GODOT=C:\path\to\Godot.exe
REM ============================================================================
setlocal EnableExtensions

set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

REM --- deteksi binary Godot ----------------------------------------------------
set "GODOT_BIN="
if defined GODOT set "GODOT_BIN=%GODOT%"
if not defined GODOT_BIN (
    for /f "delims=" %%F in ('dir /b /o-d "%LOCALAPPDATA%\Godot\Godot_v4*_win64_console.exe" 2^>nul') do (
        if not defined GODOT_BIN set "GODOT_BIN=%LOCALAPPDATA%\Godot\%%F"
    )
)
if not defined GODOT_BIN (
    for /f "delims=" %%F in ('dir /b /o-d "%LOCALAPPDATA%\Godot\Godot_v4*_win64.exe" 2^>nul') do (
        if not defined GODOT_BIN set "GODOT_BIN=%LOCALAPPDATA%\Godot\%%F"
    )
)
if not defined GODOT_BIN (
    for /f "delims=" %%F in ('where godot 2^>nul') do (
        if not defined GODOT_BIN set "GODOT_BIN=%%F"
    )
)

if not defined GODOT_BIN (
    echo.
    echo [ERROR] Binary Godot tidak ditemukan.
    echo         Cari manual di folder: "%LOCALAPPDATA%\Godot\"
    echo         atau set env var GODOT, contoh:
    echo             set GODOT=C:\Users\WIN10\AppData\Local\Godot\Godot_v4.7.2-stable_win64_console.exe
    goto :fail
)

REM --- parsing argumen --------------------------------------------------------
set "MODE=play"
set "EXTRA="

:parse_args
if "%~1"=="" goto parsed
if /i "%~1"=="--editor" goto arg_editor
if /i "%~1"=="--test" goto arg_test
if /i "%~1"=="--build" goto arg_build
if /i "%~1"=="--headless" goto arg_headless
if /i "%~1"=="--help" goto arg_help
if /i "%~1"=="-h" goto arg_help
set "EXTRA=%EXTRA% %1"
shift
goto parse_args

:arg_editor
set "MODE=editor"
shift
goto parse_args

:arg_test
set "MODE=test"
shift
goto parse_args

:arg_build
set "MODE=build"
shift
goto parse_args

:arg_headless
set "MODE=headless"
shift
goto parse_args

:arg_help
echo.
echo  Es Cekek - run.bat
echo.
echo    run.bat             main game dari source (tanpa build)
echo    run.bat --editor    buka Godot Editor
echo    run.bat --test      smoke test + boot check headless
echo    run.bat --build     export 4 platform sekaligus
echo    run.bat --headless  game tanpa jendela
echo.
echo  Godot  : %GODOT_BIN%
echo  Project: %PROJECT%
echo.
goto :end

:parsed
echo ============================================================
echo  Es Cekek - %GODOT_BIN%
echo  Project: %PROJECT%
echo ============================================================
echo.

if /i "%MODE%"=="play" goto :do_play
if /i "%MODE%"=="editor" goto :do_editor
if /i "%MODE%"=="test" goto :do_test
if /i "%MODE%"=="build" goto :do_build
if /i "%MODE%"=="headless" goto :do_headless
echo [ERROR] Mode tidak dikenal.
goto :fail

REM ---------------------------------------------------------------------------
:do_play
echo [RUN] Menjalankan game dari source code (tanpa export).
echo.
echo   WASD  = jalan          E/F  = interact (buka meja)
echo   Mouse = lihat         Q    = tukar tangan
echo   R     = putar badan    Esc  = keluar
echo.
"%GODOT_BIN%" --path "%PROJECT%" %EXTRA%
goto :after_game

:do_headless
echo [RUN] Menjalakan game headless (tanpa jendela)...
"%GODOT_BIN%" --headless --path "%PROJECT%" %EXTRA%
goto :after_game

:do_editor
echo [EDITOR] Membuka Godot Editor...
"%GODOT_BIN%" --editor --path "%PROJECT%" %EXTRA%
goto :after_game

:do_test
echo [TEST] Menjalankan smoke test + boot check...
echo.
call "%PROJECT%\scripts\run_tests.cmd" --boot
if errorlevel 1 goto :fail
goto :end

REM ---------------------------------------------------------------------------
REM  Export 4 platform sekaligus (bukan satu per satu).
REM  Android WAJIB --export-debug (tidak ada release keystore) - lihat gotcha #21.
REM ---------------------------------------------------------------------------
:do_build
echo [BUILD] Export 4 platform sekaligus ke folder build\
echo.
set "FAILED="

echo --- Windows Desktop ---
"%GODOT_BIN%" --headless --path "%PROJECT%" --export-release "Windows Desktop"
if errorlevel 1 set "FAILED=Windows Desktop"

echo --- Linux ---
"%GODOT_BIN%" --headless --path "%PROJECT%" --export-release "Linux"
if errorlevel 1 set "FAILED=%FAILED% Linux"

echo --- macOS ---
"%GODOT_BIN%" --headless --path "%PROJECT%" --export-release "macOS"
if errorlevel 1 set "FAILED=%FAILED% macOS"

echo --- Android (--export-debug) ---
"%GODOT_BIN%" --headless --path "%PROJECT%" --export-debug "Android"
if errorlevel 1 set "FAILED=%FAILED% Android"

echo.
if defined FAILED (
    echo [WARN] Export GAGAL untuk:%FAILED%
    echo        Cek export template + Android SDK/JDK.
    goto :fail
)
echo [OK] Semua build selesai:
echo     build\windows\EsCekek.exe
echo     build\linux\EsCekek.x86_64
echo     build\macos\EsCekek.zip
echo     build\android\EsCekek.apk
goto :end

:after_game
if errorlevel 1 goto :fail
echo.
echo [OK] Selesai.
goto :end

:fail
echo.
echo [FAIL] Ada yang gagal (exit %ERRORLEVEL%).
:end
echo.
pause >nul
endlocal
exit /b 0
