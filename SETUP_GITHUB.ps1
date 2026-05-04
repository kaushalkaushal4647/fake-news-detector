#Requires -Version 5.1
<#
  Automates: sync project1.html → index.html, commit, create GitHub repo, push.

  ONE step you must do (GitHub does not allow anyone else to log in as you):
  Create a token: https://github.com/settings/tokens
    Classic: enable scope "repo"
    Fine-grained: Repository access All repos OR only the new one; Permissions → Contents Read/Write

  Then in PowerShell:

    cd "c:\Users\kaush\OneDrive\Desktop\python\web-deploy"
    $env:GITHUB_TOKEN = "ghp_xxxxxxxx"   # paste token (session only — do not save in a file)
    .\SETUP_GITHUB.ps1

  Optional repo name (default: fake-news-detector-site):
    .\SETUP_GITHUB.ps1 -RepoName "my-site-name"

  After success: GitHub → your repo → Settings → Pages → Deploy from branch "main" / "(root)" → Save
  Site URL: https://YOURNAME.github.io/REPO/
#>
param(
  [string]$RepoName = "fake-news-detector-site"
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
Set-Location $here

function Get-GhExe {
  $cmd = Get-Command "gh" -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $p = "C:\Program Files\GitHub CLI\gh.exe"
  if (Test-Path $p) { return $p }
  return $null
}

# --- 1) Sync from parent project1.html ---
$parentHtml = Join-Path (Split-Path $here -Parent) "project1.html"
if (Test-Path $parentHtml) {
  Copy-Item $parentHtml (Join-Path $here "index.html") -Force
  Write-Host "Synced project1.html -> index.html" -ForegroundColor Green
}

# --- 2) Commit ---
git add -A
$st = git status --porcelain
if ($st) {
  git -c user.email="noreply@users.noreply.github.com" -c user.name="Deploy Script" commit -m "Deploy: sync site"
  Write-Host "Committed." -ForegroundColor Green
} else {
  Write-Host "Git: nothing to commit."
}

$token = $null
if ($env:GITHUB_TOKEN) { $token = $env:GITHUB_TOKEN.Trim() }
elseif ($env:GH_TOKEN) { $token = $env:GH_TOKEN.Trim() }

if (-not $token -or $token.Length -lt 10) {
  Write-Host ""
  Write-Host "Missing token. Set one for this session, then run again:" -ForegroundColor Yellow
  Write-Host '  $env:GITHUB_TOKEN = "ghp_..."' -ForegroundColor Cyan
  Write-Host "  .\SETUP_GITHUB.ps1" -ForegroundColor Cyan
  Write-Host ""
  exit 1
}

$gh = Get-GhExe
if (-not $gh) {
  Write-Host "GitHub CLI (gh) not found. Install: winget install GitHub.cli" -ForegroundColor Red
  exit 1
}

# --- 3) Log gh in with token (non-interactive) ---
Write-Host "Logging in to GitHub API via gh..." -ForegroundColor DarkGray
$token | & $gh auth login --with-token 2>&1 | Out-Null

# --- 4) Remove old remote if present ---
git remote remove origin 2>$null

# --- 5) Create repo on GitHub and push this folder ---
Write-Host "Creating repo '$RepoName' and pushing branch main..." -ForegroundColor Cyan
try {
  & $gh repo create $RepoName --public --source=. --remote=origin --push --description "Fake News Detector (static HTML)"
} catch {
  Write-Host "gh repo create failed. If the repo already exists, run:" -ForegroundColor Yellow
  Write-Host "  git remote add origin https://github.com/<YOU>/$RepoName.git" -ForegroundColor Yellow
  Write-Host "  git push -u origin main" -ForegroundColor Yellow
  throw
}

$user = (& $gh api user -q .login)
Write-Host ""
Write-Host "Done. Repository: https://github.com/$user/$RepoName" -ForegroundColor Green
Write-Host ""
Write-Host "Enable GitHub Pages (once):" -ForegroundColor Cyan
Write-Host "  https://github.com/$user/$RepoName/settings/pages"
Write-Host "  Source: Deploy from branch  →  main  →  / (root)  →  Save"
Write-Host ""
Write-Host "Your site will be:" -ForegroundColor Cyan
Write-Host "  https://${user}.github.io/${RepoName}/"
Write-Host ""
Write-Host "Clear token from this shell when finished:" -ForegroundColor DarkGray
Write-Host '  Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue; Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue'
Write-Host ""
