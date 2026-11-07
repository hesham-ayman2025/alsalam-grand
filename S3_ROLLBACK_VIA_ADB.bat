@echo off
setlocal
set "ADB=C:\platform-tools\adb.exe"
set "TV=192.168.101.5:5555"
set "PH=/system/app/Philipslauncher/Philipslauncher.apk"
"%ADB%" connect %TV%
"%ADB%" -s %TV% root
timeout /t 4 /nobreak >nul
"%ADB%" connect %TV%
"%ADB%" -s %TV% remount
"%ADB%" -s %TV% shell "[ -f %PH%.alsalam-bak ] && mv %PH%.alsalam-bak %PH%"
"%ADB%" -s %TV% shell rm -r /system/priv-app/AlSalamGrandHome
"%ADB%" -s %TV% shell pm enable com.android.mslauncher
"%ADB%" -s %TV% shell sync
"%ADB%" -s %TV% shell ls -l %PH%
echo Rolled back. Reboot the TV.
pause
