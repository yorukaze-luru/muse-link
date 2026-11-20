# Muse Link: build and (when the version is ahead) release script.
# The GitHub workflow is only a thin launcher for this file, so release
# logic can be updated by pushing this script alone.
$ErrorActionPreference = 'Stop'

# Restore icons from base64
[IO.File]::WriteAllBytes('assets/icon.ico', [Convert]::FromBase64String((Get-Content 'assets/icon.ico.b64' -Raw)))
[IO.File]::WriteAllBytes('assets/icon.png', [Convert]::FromBase64String((Get-Content 'assets/icon.png.b64' -Raw)))

npm ci
$v = (Get-Content package.json -Raw | ConvertFrom-Json).version

# Keep the plugin manifest version in sync with package.json
$m = Get-Content muse-plugin.json -Raw | ConvertFrom-Json
$m.version = $v
$m | ConvertTo-Json | Set-Content muse-plugin.json -Encoding utf8

# Decide: release when forced, or when package.json is ahead of the latest release
$rel = gh api "repos/$env:GITHUB_REPOSITORY/releases" | ConvertFrom-Json
$main = $rel | Where-Object { $_.tag_name -match '^v[0-9]' } | Select-Object -First 1
$isRelease = ($env:FORCE_RELEASE -eq 'true') -or (-not $main) -or ($main.tag_name -ne "v$v")

npx electron-builder --win zip --publish never
if (-not $isRelease) { exit 0 }

# --- Release run ---
$tag = "v$v"
$zip = Get-ChildItem 'dist/*.zip' | Select-Object -First 1
Copy-Item $zip.FullName "dist/Muse-Link-Plugin-$v.zip"
@("version: $v", "path: Muse-Link-Plugin-$v.zip") | Set-Content "dist/link.yml" -Encoding ascii
gh release view $tag --json tagName 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
  gh release upload $tag "dist/Muse-Link-Plugin-$v.zip" "dist/link.yml" --clobber
  gh release edit $tag --title "Muse Link v$v" --notes-file RELEASE_NOTES.md
} else {
  gh release create $tag --title "Muse Link v$v" --notes-file RELEASE_NOTES.md "dist/Muse-Link-Plugin-$v.zip" "dist/link.yml"
}
