# 1. Install and use the latest LTS version of Node.js using nvm-windows
nvm install lts
if ($LASTEXITCODE -eq 0) {
    Write-Host "LTS version installation completed."
} else {
    Write-Error "Failed to install Node.js LTS version."
}

nvm use lts
if ($LASTEXITCODE -eq 0) {
    Write-Host "Started using the LTS version."
} else {
    Write-Error "Failed to set up LTS version for use."
}

# 2. Globally install pnpm via npm
npm install -g pnpm
if ($LASTEXITCODE -eq 0) {
    Write-Host "Global installation of pnpm completed."
} else {
    Write-Error "Failed to install pnpm."
}

# 3. pnpm Environment Setup (Check installation path and version)
Write-Host "`n--- pnpm Installation Path and Version Check ---"
pnpm -v
if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully displayed pnpm version. Environment PATH is correctly configured."
} else {
    Write-Error "Failed to execute pnpm. Please check the system PATH."
}

# 4. Globally install required packages using pnpm
pnpm add -g @akashic/akashic-cli textlint textlint-rule-preset-ja-technical-writing
if ($LASTEXITCODE -eq 0) {
    Write-Host "Installation of required global packages completed."
} else {
    Write-Error "Failed to install global packages."
}
