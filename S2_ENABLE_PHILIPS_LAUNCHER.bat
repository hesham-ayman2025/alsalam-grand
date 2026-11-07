@echo off
setlocal
set "ADB=C:\platform-tools\adb.exe"
set "TV=192.168.101.5:5555"
"%ADB%" connect %TV%
"%ADB%" -s %TV% shell pm enable com.android.mslauncher
"%ADB%" -s %TV% shell am start -W -n com.android.mslauncher/.LauncherActivity
echo Philips launcher enabled again.
pause
