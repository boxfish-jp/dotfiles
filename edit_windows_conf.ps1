# ----------------------------------------------------
# Please run PowerShell "As Administrator" before execution.
# ----------------------------------------------------

# Check and change execution policy (required for script execution)
Write-Host "Temporarily setting PowerShell execution policy to Bypass..." -ForegroundColor Blue
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Write-Host ""

# ----------------------------------------------------
# 1. Disable Fast Startup
# ----------------------------------------------------
Write-Host "1. Disabling Fast Startup (powercfg /h off)..." -ForegroundColor Yellow
powercfg /h off
Write-Host "   -> Fast Startup disabled successfully." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 2. Disable Mouse Acceleration (Disable Enhance pointer precision)
# ----------------------------------------------------
Write-Host "2. Disabling Mouse Acceleration (Enhance pointer precision)..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value 0 -Type String
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value 0 -Type String
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value 0 -Type String
Write-Host "   -> Mouse acceleration disabled successfully." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 3. Change Win11 right-click menu to Classic style
# ----------------------------------------------------
Write-Host "3. Changing Windows 11 right-click menu to Classic style..." -ForegroundColor Yellow
$CLSID = "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
$Path = "HKCU:\Software\Classes\CLSID\$CLSID\InprocServer32"
# Create key and set (Default) value to empty to enable Classic menu
If (-not (Test-Path $Path)) {
    New-Item -Path $Path -Force | Out-Null
    Set-ItemProperty -Path $Path -Name "(Default)" -Value "" -Force
}
Write-Host "   -> Classic right-click menu setting completed." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 4. Taskbar Customization and Button Hiding
# ----------------------------------------------------
Write-Host "4. Aligning Taskbar Left and hiding buttons (Search, Task View, Widgets, Chat)..." -ForegroundColor Yellow
$TaskbarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# 4-1. Change Taskbar alignment to Left (0: Left-aligned)
Set-ItemProperty -Path $TaskbarPath -Name "TaskbarAl" -Type DWord -Value 0

# 4-2. Disable Task View (0: Hidden)
Set-ItemProperty -Path $TaskbarPath -Name "ShowTaskViewButton" -Type DWord -Value 0

# 4-3. Disable Widgets (0: Hidden)
Set-ItemProperty -Path $TaskbarPath -Name "TaskbarDa" -Type DWord -Value 0

# 4-4. Hide Chat (Teams) (0: Hidden)
Set-ItemProperty -Path $TaskbarPath -Name "TaskbarMn" -Type DWord -Value 0

# 4-5. Hide Search Icon (0: Hidden)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 0

Write-Host "   -> Taskbar customization settings completed." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 5. Set to Dark Mode
# ----------------------------------------------------
Write-Host "5. Setting system to Dark Mode..." -ForegroundColor Yellow
$ThemePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
# Set App theme to Dark Mode (0)
Set-ItemProperty -Path $ThemePath -Name "AppsUseLightTheme" -Value 0 -Type DWord
# Set System theme to Dark Mode (0)
Set-ItemProperty -Path $ThemePath -Name "SystemUsesLightTheme" -Value 0 -Type DWord
Write-Host "   -> Dark Mode setting completed." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 6. Show Hidden Files
# ----------------------------------------------------
Write-Host "6. Enabling display of hidden files..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 1
Write-Host "   -> Hidden files display setting completed." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 7. Show File Extensions
# ----------------------------------------------------
Write-Host "7. Enabling display of file extensions..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideExt" -Type DWord -Value 0
Write-Host "   -> File extension display setting completed." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 8. Display Full Path in File Explorer Title Bar
# ----------------------------------------------------
Write-Host "8. Displaying full path in File Explorer title bar..." -ForegroundColor Yellow
# Set FullPath to 1 (1: Show)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name "FullPath" -Type DWord -Value 1
Write-Host "   -> File Explorer full path display setting completed." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 9. Disable Thumbs.db creation (Network folders only)
# ----------------------------------------------------
Write-Host "9. Disabling Thumbs.db creation on network folders..." -ForegroundColor Yellow
# Set DisableThumbnailsOnNetworkFolders to 1 (1: Disable)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "DisableThumbnailsOnNetworkFolders" -Type DWord -Value 1
Write-Host "   -> Thumbs.db creation disabled successfully." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 10. Disable Window Snap-related features
# ----------------------------------------------------
Write-Host "10. Disabling Window Snap-related features..." -ForegroundColor Yellow
$SnapPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Disable Snap Assist (0: Disabled)
Set-ItemProperty -Path $SnapPath -Name "SnapAssist" -Type DWord -Value 0

# Disable Snap Assist Flyout (Suggested layout feature) (0: Disabled)
Set-ItemProperty -Path $SnapPath -Name "EnableSnapAssistFlyout" -Type DWord -Value 0

# Disable DITest (0: Disabled)
Set-ItemProperty -Path $SnapPath -Name "DITest" -Type DWord -Value 0

Write-Host "   -> Window Snap-related features disabled successfully." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# Apply Settings
# ----------------------------------------------------
Write-Host "Restarting Explorer to apply settings (Recommended)..." -ForegroundColor Blue
# Forcefully terminate and restart the Explorer process
Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process "explorer"
Write-Host "Explorer restart completed. Most settings have been applied." -ForegroundColor Blue

# ----------------------------------------------------
# Complete
# ----------------------------------------------------
Write-Host "`nAll settings have been configured. Some settings will fully apply after a system reboot." -ForegroundColor Cyan
