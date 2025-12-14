@echo off
setlocal EnableExtensions
set "_ROOT=%~dp0.."
set "_SCRIPT=%_ROOT%\RemoveBookmarkDuplicates.ps1"

where pwsh.exe >nul 2>&1 && (
  pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%_SCRIPT%" %*
) || (
  powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%_SCRIPT%" %*
)
endlocal
