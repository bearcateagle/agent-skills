$ErrorActionPreference = "Stop"

Write-Host "1. Upgrading Codex Git marketplaces (pstack-claude and mattpocock)..."
codex plugin marketplace upgrade pstack-claude
codex plugin marketplace upgrade mattpocock

Write-Host "2. Refreshing Codex plugins..."
foreach ($plugin in @("pstack@pstack-claude", "mattpocock-skills@mattpocock")) {
  $out = & codex plugin add $plugin 2>&1
  if ($LASTEXITCODE -eq 0) {
    $out | ForEach-Object { Write-Host "  $_" }
  } elseif (($out -join "`n") -match "os error 5|Access is denied") {
    Write-Host "  Skipped live cache swap for $plugin (Windows file lock while Codex is open; restart Codex to pick up any version bump)."
  } else {
    throw "codex plugin add $plugin failed: $($out -join "`n")"
  }
}

$pstackSrc = "$HOME\.codex\.tmp\marketplaces\pstack-claude\plugins\pstack"
$mpSrc = "$HOME\.codex\.tmp\marketplaces\mattpocock"

if (-not (Test-Path "$pstackSrc\skills")) {
  throw "Could not find pstack source at $pstackSrc"
}
if (-not (Test-Path "$mpSrc\skills")) {
  throw "Could not find mattpocock source at $mpSrc"
}

Write-Host "3. Syncing pstack plugin to Antigravity..."
$agPstack = "$HOME\.gemini\config\plugins\pstack"
if (Test-Path $agPstack) { Remove-Item -Recurse -Force $agPstack }
Copy-Item -Recurse -Force $pstackSrc $agPstack

$hooksObj = @{
  "pstack-routing" = @{
    "SessionStart" = @(
      @{
        "type" = "command"
        "command" = '"C:\Program Files\Git\bin\sh.exe" ./hooks/session-start.sh agy'
      }
    )
  }
}
$hooksObj | ConvertTo-Json -Depth 6 | Set-Content -Path "$agPstack\hooks.json" -Encoding UTF8

Write-Host "4. Syncing mattpocock-skills plugin to Antigravity (flattened 1 level deep)..."
$agMp = "$HOME\.gemini\config\plugins\mattpocock-skills"
if (Test-Path $agMp) { Remove-Item -Recurse -Force $agMp }
New-Item -ItemType Directory -Path "$agMp\skills" -Force | Out-Null

$skillFiles = Get-ChildItem "$mpSrc\skills" -Recurse -Filter "SKILL.md"
foreach ($sf in $skillFiles) {
  $skillDir = $sf.Directory
  Copy-Item -Recurse -Force $skillDir.FullName "$agMp\skills\$($skillDir.Name)"
}

$mpCommit = (git -C $mpSrc rev-parse --short HEAD).Trim()
$mpPkgPath = "$mpSrc\.claude-plugin\plugin.json"
$mpVersion = "1.0.0-$mpCommit"
if (Test-Path $mpPkgPath) {
  $mpMeta = Get-Content $mpPkgPath -Raw | ConvertFrom-Json
  if ($mpMeta.version) { $mpVersion = $mpMeta.version }
}

@{
  name = "mattpocock-skills"
  displayName = "Matt Pocock Skills"
  version = $mpVersion
  description = "Disciplined engineering and productivity agent skills from mattpocock/skills."
  author = "Matt Pocock"
  repository = "https://github.com/mattpocock/skills"
} | ConvertTo-Json -Depth 4 | Set-Content -Path "$agMp\plugin.json" -Encoding UTF8

$psCount = (Get-ChildItem "$agPstack\skills" -Directory).Count
$mpCount = (Get-ChildItem "$agMp\skills" -Directory).Count
$psCommit = (git -C "$HOME\.codex\.tmp\marketplaces\pstack-claude" rev-parse --short HEAD).Trim()

Write-Host "Done."
Write-Host "  pstack:            $psCount skills (commit $psCommit)"
Write-Host "  mattpocock-skills: $mpCount skills (v$mpVersion, commit $mpCommit)"
