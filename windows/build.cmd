@echo off
setlocal
set "STILLHERE_ROOT=%~dp0.."
set "STILLHERE_CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%STILLHERE_CSC%" set "STILLHERE_CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%STILLHERE_CSC%" (
  echo The .NET Framework C# compiler is unavailable.
  exit /b 1
)
if not exist "%STILLHERE_ROOT%\dist\windows" mkdir "%STILLHERE_ROOT%\dist\windows"
"%STILLHERE_CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 ^
 /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll ^
 /reference:System.Windows.Forms.dll /reference:System.Runtime.Serialization.dll ^
 /reference:System.Security.dll ^
 /win32manifest:"%STILLHERE_ROOT%\windows\app.manifest" ^
 /win32icon:"%STILLHERE_ROOT%\assets\AppIcon.ico" ^
 /resource:"%STILLHERE_ROOT%\Sources\StillHere\Resources\ExistentialCapybara.png",StillHere.DefaultWallpaper ^
 /out:"%STILLHERE_ROOT%\dist\windows\StillHere.exe" "%STILLHERE_ROOT%\windows\*.cs"
exit /b %errorlevel%
