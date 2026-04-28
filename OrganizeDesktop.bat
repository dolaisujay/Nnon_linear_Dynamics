@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==============================================================================
rem  OrganizeDesktop.bat
rem
rem  Moves files and folders from the current user's Desktop into categorized
rem  subfolders.
rem
rem  Usage:
rem    OrganizeDesktop.bat [--dry-run] [--no-pause]
rem
rem  Notes:
rem  - Uses PowerShell (Windows built-in). No admin rights required.
rem  - Excludes this script and desktop.ini.
rem ==============================================================================

set "DRY_RUN=0"
set "DO_PAUSE=1"

:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--dry-run" (set "DRY_RUN=1" & shift & goto :parse_args)
if /I "%~1"=="--no-pause" (set "DO_PAUSE=0" & shift & goto :parse_args)
shift
goto :parse_args

:args_done
echo Organizing Desktop... (dry-run=%DRY_RUN%)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$dryRun = [bool]([int]'%DRY_RUN%');" ^
  "$desktop = [Environment]::GetFolderPath('Desktop');" ^
  "if (-not (Test-Path -LiteralPath $desktop)) { throw ('Desktop path not found: ' + $desktop) }" ^
  "$folders = @('Images','Documents','Archives','Shortcuts','Code_and_Data','Folders');" ^
  "foreach ($name in $folders) {" ^
  "  $path = Join-Path $desktop $name;" ^
  "  if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path | Out-Null }" ^
  "}" ^
  "$excludedFiles = @('desktop.ini', 'OrganizeDesktop.bat');" ^
  "$files = Get-ChildItem -LiteralPath $desktop -File | Where-Object { $_.Name -notin $excludedFiles };" ^
  "foreach ($f in $files) {" ^
  "  $ext = ($f.Extension ?? '').ToLowerInvariant();" ^
  "  if ($ext -match '\\.(jpg|jpeg|png|gif)$') { $dest = 'Images' }" ^
  "  elseif ($ext -match '\\.(pdf|docx|txt|html|xlsx|log|crt)$') { $dest = 'Documents' }" ^
  "  elseif ($ext -match '\\.(zip|iso|rar|7z)$') { $dest = 'Archives' }" ^
  "  elseif ($ext -match '\\.(lnk)$') { $dest = 'Shortcuts' }" ^
  "  elseif ($ext -match '\\.(js|hex|fig|drl|rpt|gbr|sldprt)$') { $dest = 'Code_and_Data' }" ^
  "  else { $dest = 'Documents' }" ^
  "  $target = Join-Path $desktop $dest;" ^
  "  if ($dryRun) { Write-Host ('[DRY-RUN] Move ' + $f.FullName + ' -> ' + $target) }" ^
  "  else { Move-Item -LiteralPath $f.FullName -Destination $target -Force }" ^
  "}" ^
  "$dirs = Get-ChildItem -LiteralPath $desktop -Directory | Where-Object { $_.Name -notin $folders };" ^
  "foreach ($d in $dirs) {" ^
  "  $target = Join-Path $desktop 'Folders';" ^
  "  if ($dryRun) { Write-Host ('[DRY-RUN] Move ' + $d.FullName + ' -> ' + $target) }" ^
  "  else { Move-Item -LiteralPath $d.FullName -Destination $target -Force }" ^
  "}"

if errorlevel 1 (
  echo.
  echo Desktop organization failed.
  exit /b 1
)

echo Desktop organized successfully!
if "%DO_PAUSE%"=="1" pause
exit /b 0

