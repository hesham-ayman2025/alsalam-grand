@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
REM Stage 2: reversible experiment. Disables (does NOT delete) the Philips launcher for user 0.
REM Undo any time: S2_ENABLE_PHILIPS_LAUNCHER.bat  (needs ADB over LAN to stay up).
set "ADB=C:\platform-tools\adb.exe"
set "TV=192.168.101.5:5555"
"%ADB%" connect %TV%
set "MODEL="
for /f "tokens=1" %%M in ('"%ADB%" -s %TV% shell getprop ro.product.model') do set "MODEL=%%M"
if /I not "!MODEL!"=="TV348_DVB" (echo ERROR: unexpected model [!MODEL!] & pause & exit /b 1)
"%ADB%" -s %TV% shell pm list packages com.alsalamgrand.rom | findstr /C:"com.alsalamgrand.rom" >nul
if errorlevel 1 (echo ERROR: run S1_INSTALL_APK_TEST.bat first & pause & exit /b 1)
echo Disabling com.android.mslauncher (reversible)...
"%ADB%" -s %TV% shell pm disable-user --user 0 com.android.mslauncher
"%ADB%" -s %TV% shell input keyevent KEYCODE_HOME
echo.
echo Now test: HOME key, MENU/Settings key, SOURCE/INPUT key, volume, power, standby/wake, reboot.
echo Write down every key that misbehaves. To undo: S2_ENABLE_PHILIPS_LAUNCHER.bat
pause
