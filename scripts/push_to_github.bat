@echo off
setlocal enabledelayedexpansion

REM Push helper for this repository.
REM - Prompts for GitHub login (via `gh`) if needed
REM - Stages changes, asks for a commit message, commits, and pushes

cd /d "%~dp0.."

set "REPO_URL=https://github.com/dolaisujay/Nnon_linear_Dynamics"

where git >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Git not found in PATH. Install Git for Windows and try again.
  exit /b 1
)

REM Prefer GitHub CLI for interactive login prompts
where gh >nul 2>nul
if errorlevel 1 (
  echo [WARN] GitHub CLI (gh) not found. Continuing with plain git push...
  goto :push
)

gh auth status -h github.com >nul 2>nul
if errorlevel 1 (
  echo [INFO] Not logged in to GitHub. Starting interactive login...
  gh auth login -h github.com -p https -w
  if errorlevel 1 (
    echo [ERROR] GitHub login failed.
    exit /b 1
  )
)

:push
REM Ensure we are in a git repo
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
  echo [ERROR] This folder is not a git repository.
  exit /b 1
)

REM Ensure origin remote points to the expected repo
for /f "usebackq tokens=* delims=" %%R in (`git remote get-url origin 2^>nul`) do set "ORIGIN_URL=%%R"
if "%ORIGIN_URL%"=="" (
  echo [INFO] Adding remote origin: %REPO_URL%
  git remote add origin "%REPO_URL%"
) else (
  echo [INFO] origin = %ORIGIN_URL%
)

REM Stage all changes
git add -A

REM If nothing to commit, just push (in case local is behind/ahead)
git diff --cached --quiet
if not errorlevel 1 goto :just_push

set "MSG="
set /p MSG=Commit message (leave blank for 'Update'): 
if "%MSG%"=="" set "MSG=Update"

git commit -m "%MSG%"
if errorlevel 1 (
  echo [ERROR] Commit failed.
  exit /b 1
)

:just_push
for /f "usebackq tokens=* delims=" %%B in (`git branch --show-current`) do set "BRANCH=%%B"
if "%BRANCH%"=="" set "BRANCH=main"

echo [INFO] Pushing branch %BRANCH% ...
git push -u origin "%BRANCH%"
if errorlevel 1 (
  echo [ERROR] Push failed.
  echo If you see permission/auth errors, run: gh auth login -h github.com -p https -w
  exit /b 1
)

echo [OK] Done.
exit /b 0

