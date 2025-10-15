Write-Host "Phase I: Starting Prerequisite Checks and Setup..." -ForegroundColor Yellow

# Check for Administrator Privileges
if (-not ([Security.Principal.WindowsPrincipal]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run with Administrator privileges. Stopping script."
    Exit 1
}

# Force registration of Winget service (to ensure Winget availability) [3]
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
    # --accept-source-agreements: Automatically accept source agreements
    # --silent: Attempt silent installation
    $InstallCommand = "winget install --id `"$AppId`" -e --accept-source-agreements --silent"

    Write-Host "`n--> Installing: $AppName ($AppId)" -ForegroundColor Cyan
    
    try {
        # Execute command (check for errors using PowerShell's exit code $LASTEXITCODE)
        Invoke-Expression $InstallCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [SUCCESS] $AppName installation completed." -ForegroundColor Green
        } else {
            Write-Warning "    [WARNING] $AppName finished with exit code $LASTEXITCODE, which might indicate partial failure."
            Write-Host "    Diagnostics Tip: Run 'winget error $LASTEXITCODE' for more details. [4]" -ForegroundColor DarkYellow
        }
    } catch {
        Write-Error "    [FAILURE] An exception occurred during the installation of $AppName: $($_.Exception.Message)"
    }
}

# 3. Define and Execute Installation Manifest
# -----------------------------------------------------------------------------

Write-Host "`nPhase II: Starting Application Installation..." -ForegroundColor Yellow

$PriorityApps = @(
    # Foundational Version Control
    @{Id="Git.Git"; Name="Git"}, # [5]
    # Web Browser
    @{Id="Google.Chrome"; Name="Google Chrome"}, # [6]
    # NVIDIA Driver Utility
    @{Id="NVIDIA.NVIDIAApp"; Name="NVIDIA App"}, # [7]
    @{Id="Tailscale.Tailscale"; Name="Tailscale (VPN)"}
)

# Install Priority Apps
$PriorityApps | ForEach-Object { Install-WingetPackage -AppId $_.Id -AppName $_.Name }
