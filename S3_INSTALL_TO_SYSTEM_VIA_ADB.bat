@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
REM Stage 3: make the Home part of /system (file level, no block-device writes).
REM Needs: S1 and S2 passed, backups verified. Undo: S3_ROLLBACK_VIA_ADB.bat
set "ADB=C:\platform-tools\adb.exe"
set "TV=192.168.101.5:5555"
set "APK=%~dp0AlSalamGrand-Home.apk"
set "D=/system/priv-app/AlSalamGrandHome"
set "PH=/system/app/Philipslauncher/Philipslauncher.apk"
if not exist "%APK%" (echo ERROR: AlSalamGrand-Home.apk missing & pause & exit /b 1)
"%ADB%" connect %TV%
"%ADB%" -s %TV% root
timeout /t 4 /nobreak >nul
"%ADB%" connect %TV%
"%ADB%" -s %TV% shell id | findstr /C:"uid=0" >nul
if errorlevel 1 (echo ERROR: adb root not available & pause & exit /b 1)
set "MODEL="
for /f "tokens=1" %%M in ('"%ADB%" -s %TV% shell getprop ro.product.model') do set "MODEL=%%M"
if /I not "!MODEL!"=="TV348_DVB" (echo ERROR: unexpected model [!MODEL!] & pause & exit /b 1)
"%ADB%" -s %TV% remount
"%ADB%" -s %TV% shell "touch /system/.alsalam_rw_test && rm /system/.alsalam_rw_test"
if errorlevel 1 (echo ERROR: /system is not writable - nothing changed & pause & exit /b 1)
"%ADB%" -s %TV% shell "ls %PH%" | findstr /C:"Philipslauncher.apk" >nul
if errorlevel 1 (echo ERROR: Philips launcher apk not found where expected & pause & exit /b 1)
"%ADB%" -s %TV% shell mkdir -p %D%
"%ADB%" -s %TV% push "%APK%" %D%/AlSalamGrandHome.apk.new
if errorlevel 1 (echo PUSH FAILED & pause & exit /b 1)
for %%F in ("%APK%") do set "LOCAL=%%~zF"
set "REMOTE="
for /f "tokens=1" %%S in ('"%ADB%" -s %TV% shell "wc -c < %D%/AlSalamGrandHome.apk.new"') do set "REMOTE=%%S"
if not "!LOCAL!"=="!REMOTE!" (echo SIZE MISMATCH local=!LOCAL! remote=!REMOTE! - aborting & "%ADB%" -s %TV% shell rm %D%/AlSalamGrandHome.apk.new & pause & exit /b 1)
"%ADB%" -s %TV% shell "mv %D%/AlSalamGrandHome.apk.new %D%/AlSalamGrandHome.apk && chmod 644 %D%/AlSalamGrandHome.apk && chmod 755 %D% && chown root:root %D%/AlSalamGrandHome.apk"
"%ADB%" -s %TV% shell "[ -f %PH%.alsalam-bak ] || mv %PH% %PH%.alsalam-bak"
"%ADB%" -s %TV% shell sync
echo.
echo Done. Reboot the TV and test. First boot may take longer (app optimisation).
echo If anything is wrong: S3_ROLLBACK_VIA_ADB.bat
pause
