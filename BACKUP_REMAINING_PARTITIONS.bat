@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM ============================================================
REM  Philips TV348_DVB - READ-ONLY backup of the remaining partitions
REM  Only READS from the TV (dd if=...). Never writes to the TV.
REM  Each partition is dumped TWICE; size and SHA256 must match.
REM  dd stderr goes to /dev/null on purpose: it polluted
REM  boot_original.img with 95 bytes of text last time.
REM ============================================================
set "ADB=C:\platform-tools\adb.exe"
set "TV=192.168.101.5:5555"
set "BY=/dev/block/platform/mstar_mci.0/by-name"
set "OUT=C:\platform-tools\Philips_Backup\round2"
set "REPORT=%OUT%\BACKUP_REPORT.txt"

if not exist "%ADB%" (echo ERROR: %ADB% not found & pause & exit /b 1)
if not exist "%OUT%" mkdir "%OUT%"

"%ADB%" connect %TV%
"%ADB%" -s %TV% root
timeout /t 4 /nobreak >nul
"%ADB%" connect %TV%
"%ADB%" -s %TV% shell id | findstr /C:"uid=0" >nul
if errorlevel 1 (
  echo ERROR: adb root is not available. Block devices cannot be read. Nothing was done.
  pause & exit /b 1
)

set "MODEL="
for /f "tokens=1" %%M in ('"%ADB%" -s %TV% shell getprop ro.product.model') do set "MODEL=%%M"
if /I not "!MODEL!"=="TV348_DVB" (echo ERROR: unexpected model [!MODEL!] & pause & exit /b 1)

echo Backup report %DATE% %TIME%> "%REPORT%"
set "FAILED=0"
for %%P in (system tvservice tvconfig tvdatabase tvcustomer tee RTPM MPOOL misc) do call :dump %%P

echo.
echo ===== REPORT =====
type "%REPORT%"
if "%FAILED%"=="0" (echo ALL OK) else (echo SOME PARTITIONS FAILED - do not rely on this backup)
pause
exit /b 0

:dump
set "N=%1"
set "OKFLAG=1"
echo.
echo --- %N%
"%ADB%" -s %TV% shell "blockdev --getsize64 %BY%/%N%" > "%OUT%\%N%.size.txt"
"%ADB%" -s %TV% exec-out "dd if=%BY%/%N% bs=1048576 2>/dev/null" > "%OUT%\%N%_original.img"
"%ADB%" -s %TV% exec-out "dd if=%BY%/%N% bs=1048576 2>/dev/null" > "%OUT%\%N%_verify.img"
set "H1="
set "H2="
for /f %%H in ('certutil -hashfile "%OUT%\%N%_original.img" SHA256 ^| findstr /R /X "[0-9a-f]*"') do set "H1=%%H"
for /f %%H in ('certutil -hashfile "%OUT%\%N%_verify.img" SHA256 ^| findstr /R /X "[0-9a-f]*"') do set "H2=%%H"
for %%F in ("%OUT%\%N%_original.img") do set "SZ=%%~zF"
set "EXP="
for /f "tokens=1" %%E in ('type "%OUT%\%N%.size.txt"') do set "EXP=%%E"
if not defined H1 set "OKFLAG=0"
if not "!H1!"=="!H2!" set "OKFLAG=0"
if not "!SZ!"=="!EXP!" set "OKFLAG=0"
if "!OKFLAG!"=="1" (
  echo OK   %N% size=!SZ! sha256=!H1!>> "%REPORT%"
) else (
  echo FAIL %N% size=!SZ! expected=!EXP! h1=!H1! h2=!H2!>> "%REPORT%"
  set "FAILED=1"
)
exit /b 0
