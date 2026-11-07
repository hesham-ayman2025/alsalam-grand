@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
REM Stage 1: install the Home APK as a normal app (/data). Nothing in /system changes.
set "ADB=C:\platform-tools\adb.exe"
set "TV=192.168.101.5:5555"
set "APK=%~dp0AlSalamGrand-Home.apk"
if not exist "%ADB%" (echo ERROR: adb.exe not found & pause & exit /b 1)
if not exist "%APK%" (echo ERROR: put AlSalamGrand-Home.apk next to this file & pause & exit /b 1)
"%ADB%" connect %TV%
set "MODEL="
for /f "tokens=1" %%M in ('"%ADB%" -s %TV% shell getprop ro.product.model') do set "MODEL=%%M"
if /I not "!MODEL!"=="TV348_DVB" (echo ERROR: unexpected model [!MODEL!] & pause & exit /b 1)
"%ADB%" -s %TV% install -r "%APK%"
if errorlevel 1 (echo INSTALL FAILED - copy the message above & pause & exit /b 1)
"%ADB%" -s %TV% shell am start -n com.alsalamgrand.rom/.HomeActivity
echo.
echo Test now with the real remote: arrows, OK, BACK, channels, CH+/CH-, numbers.
echo Philips launcher is untouched. Press HOME on the remote to return to it.
pause
