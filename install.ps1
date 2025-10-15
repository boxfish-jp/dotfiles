Write-Host "Phase I: Starting Prerequisite Checks and Setup..." -ForegroundColor Yellow

# Check for Administrator Privileges
if (-not ([Security.Principal.WindowsPrincipal]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run with Administrator privileges. Stopping script."
    Exit 1
}

# Temporarily bypass execution policy (to allow external scripts like Chocolatey)
Set-ExecutionPolicy Bypass -Scope Process -Force

# Force registration of Winget service (to ensure Winget is available, especially on new OS images) [1]
Write-Host "Attempting to force Winget client registration..."
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5
Write-Host "WinGet client is ready."

# 2. Define Helper Function: Install-WingetPackage
# -----------------------------------------------------------------------------

function Install-WingetPackage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppId,

        [string]$AppName = $AppId
    )
    
    # Construct Winget installation command
    # -e: Exact ID matching
    # --accept-source-agreements: Automatically accept source agreements [2]
    # --silent: Attempt silent installation
    $InstallCommand = "winget install --id `"$AppId`" -e --accept-source-agreements --silent"

    Write-Host "`n--> Installing: $AppName ($AppId)" -ForegroundColor Cyan
    
    try {
        # Execute command (check for errors using PowerShell's exit code $LASTEXITCODE) [3]
        Invoke-Expression $InstallCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [SUCCESS] $AppName installation completed." -ForegroundColor Green
        } else {
            Write-Warning "    [WARNING] $AppName finished with exit code $LASTEXITCODE, which might indicate partial failure."
            Write-Host "    Diagnostics Tip: Run 'winget error $LASTEXITCODE' for more details." [4] -ForegroundColor DarkYellow
        }
    } catch {
        Write-Error "    [FAILURE] An exception occurred during the installation of $AppName: $($_.Exception.Message)"
    }
}

# 3. Package Manager Bootstrapping: Chocolatey (Choco)
# -----------------------------------------------------------------------------

Write-Host "`nPhase II: Bootstrapping Package Manager: Chocolatey (Choco)..." -ForegroundColor Yellow

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found. Starting bootstrap."
    try {
        # Official recommended PowerShell bootstrap command [5]
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; 
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "    [SUCCESS] Chocolatey installation completed." -ForegroundColor Green
    } catch {
        Write-Error "    [FAILURE] An exception occurred during Chocolatey installation: $($_.Exception.Message)"
    }
} else {
    Write-Host "Chocolatey is already installed. Skipping."
}

# 4. Define Installation Manifest
# -----------------------------------------------------------------------------

# Categorize applications into logical groups, considering dependencies.

$CoreDevTools = @(
    @{Id="BurntSushi.ripgrep"; Name="Ripgrep (rg)"},
    # NVM
    @{Id="Schniz.fnm"; Name="fnm (Fast Node Manager)"},
    @{Id="OBSStudio.OBSStudio"; Name="OBS Studio"},
    @{Id="Corsair.iCUE.5"; Name="Corsair iCUE v5"} # [13]
)

$ProductivityAndEditors = @(
    # Editors
    @{Id="Microsoft.VisualStudioCode"; Name="VS Code"},
    @{Id="Neovim.Neovim"; Name="Neovim"},
    # Browsers
    @{Id="Google.Chrome"; Name="Google Chrome"}, # [7]
    @{Id="Mozilla.Firefox"; Name="Mozilla Firefox"}, # [7]
    # Utility/Enhancement
    @{Id="Microsoft.PowerToys"; Name="PowerToys"}, # [2]
    @{Id="Discord.Discord"; Name="Discord"}, # [7]
    @{Id="Microsoft.Office"; Name="Microsoft 365 (Office)"}, # [8]
    @{Id="apple.itunes"; Name="Apple iTunes"} # MS Store Integration [9]
)

$AdvancedDevAndUtility = @(
    # Git-dependent tools
    @{Id="jesseduffield.lazygit"; Name="lazygit"},
    @{Id="GitHub.cli"; Name="GitHub CLI"},
    # Terminal tools and Utilities
    @{Id="Wez.WezTerm"; Name="WezTerm"},
    @{Id="Starship.Starship"; Name="Starship Prompt"},
    @{Id="Junno.fzf"; Name="FZF"},
    @{Id="astral.uv"; Name="uv (Python Installer)"},
    @{Id="Rufus.Rufus"; Name="Rufus (Bootable USB)"},
    @{Id="Ollama.Ollama"; Name="Ollama (LLM Runtime)"}, # [10]
    @{Id="yt-dlp.yt-dlp"; Name="yt-dlp"}, # [11]
    # System Utilities (IDs are assumed. Potential for failure)
    @{Id="CrystalDiskInfo.CrystalDiskInfo"; Name="Crystal Disk Info (Assumed)"},
    @{Id="TwinkleTray.TwinkleTray"; Name="Twinkle Tray (Assumed)"} 
)

$MultimediaAndGaming = @(
    # Multimedia
    @{Id="FFmpeg.FFmpeg"; Name="FFmpeg"},
    @{Id="VideoLAN.VLC"; Name="VLC Media Player"}, # [7]
    @{Id="Spotify.Spotify"; Name="Spotify"}, # [7]
    @{Id="Voicevox.Voicevox"; Name="Voicevox"},
    @{Id="BlenderFoundation.Blender"; Name="Blender (3D Suite)"}, # [12]
    # Gaming & Emulation
    @{Id="Valve.Steam"; Name="Steam"},
    @{Id="EpicGames.EpicGamesLauncher"; Name="Epic Games Launcher"},
    @{Id="osu.osu!"; Name="osu!"},
    @{Id="BlueStacks.BlueStacks"; Name="BlueStacks"}
    # System Component
)

# 5. Execute Installation
# -----------------------------------------------------------------------------

Write-Host "`nPhase III: Starting Application Installation..." -ForegroundColor Yellow

# Core Development Tools (Foundational dependencies)
$CoreDevTools | ForEach-Object { Install-WingetPackage -AppId $_.Id -AppName $_.Name }

# Productivity and Editors
$ProductivityAndEditors | ForEach-Object { Install-WingetPackage -AppId $_.Id -AppName $_.Name }

# Advanced Development Utilities
$AdvancedDevAndUtility | ForEach-Object { Install-WingetPackage -AppId $_.Id -AppName $_.Name }

# Multimedia and Gaming
$MultimediaAndGaming | ForEach-Object { Install-WingetPackage -AppId $_.Id -AppName $_.Name }

