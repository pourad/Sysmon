@echo off
REM ============================================================================
REM  build_release.bat  -  builds SysMon: Python backend + Flutter app + Setup.exe
REM  Run it from the project root (the folder that contains pubspec.yaml).
REM  Needs: Flutter, Python in PATH, and Inno Setup 6 (for the final Setup.exe).
REM ============================================================================
setlocal
set REL=build\windows\x64\runner\Release

echo.
echo [1/5] Building the Python backend (PyInstaller)...
pushd backend
python -m pip install pyinstaller psutil pynvml || goto :fail
python -m PyInstaller --noconfirm --onedir --noconsole --name monitor_backend --hidden-import pynvml monitor_backend.py || goto :fail
popd

echo.
echo [2/5] Building the Flutter app...
call flutter build windows --release || goto :fail

echo.
echo [3/5] Copying the backend next to the app...
xcopy /E /I /Y backend\dist\monitor_backend "%REL%\backend" >nul || goto :fail

REM Optional: LibreHardwareMonitor (CPU / SSD temperatures). Put its files in a folder named "lhm".
if exist lhm (
  echo Copying bundled LibreHardwareMonitor...
  xcopy /E /I /Y lhm "%REL%\lhm" >nul
) else (
  echo No "lhm" folder found - CPU/SSD temperatures will need LibreHardwareMonitor installed separately.
)

echo.
echo [4/5] Copying Visual C++ runtime DLLs so the app runs on PCs without them...
for %%F in (msvcp140.dll vcruntime140.dll vcruntime140_1.dll) do (
  if exist "%SystemRoot%\System32\%%F" copy /Y "%SystemRoot%\System32\%%F" "%REL%\" >nul
)

echo.
echo [5/5] Building the installer with Inno Setup...
set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" goto :noinno
"%ISCC%" installer.iss || goto :fail

echo.
echo DONE.  Installer:  Output\SysMon-Setup.exe
exit /b 0

:noinno
echo.
echo Inno Setup 6 was not found, so Setup.exe was not built.
echo Install it from https://jrsoftware.org/isinfo.php and run this file again,
echo or open installer.iss with Inno Setup and press Compile.
echo The app folder is ready here:  %REL%
exit /b 0

:fail
echo.
echo BUILD FAILED - see the error above.
exit /b 1
