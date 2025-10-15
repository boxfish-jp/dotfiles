# ----------------------------------------------------
# 実行前にPowerShellを「管理者として実行」してください。
# ----------------------------------------------------

# 実行ポリシーの確認と変更 (スクリプト実行に必要)
Write-Host "PowerShellの実行ポリシーを一時的にBypassに設定します..." -ForegroundColor Blue
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Write-Host ""

# ----------------------------------------------------
# 1. 高速スタートアップ無効
# ----------------------------------------------------
Write-Host "1. 高速スタートアップを無効にします (powercfg /h off)..." -ForegroundColor Yellow
powercfg /h off
Write-Host "   -> 高速スタートアップ無効化が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 2. マウスの加速を切る (ポインターの精度向上を無効化)
# ----------------------------------------------------
Write-Host "2. マウスの加速 (ポインターの精度向上) を無効にします..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value 0 -Type String
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value 0 -Type String
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value 0 -Type String
Write-Host "   -> マウスの加速無効化が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 3. Win11の右クリックメニューをクラシック形式に変更
# ----------------------------------------------------
Write-Host "3. Windows 11 の右クリックメニューをクラシック形式に変更します..." -ForegroundColor Yellow
$CLSID = "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
$Path = "HKCU:\Software\Classes\CLSID\$CLSID\InprocServer32"
# キーを作成し、(既定)の値を空に設定することでクラシックメニューを有効化
If (-not (Test-Path $Path)) {
    New-Item -Path $Path -Force | Out-Null
    Set-ItemProperty -Path $Path -Name "(Default)" -Value "" -Force
}
Write-Host "   -> 右クリックメニューのクラシック化設定が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 4. タスクバーのカスタマイズとボタンの非表示
# ----------------------------------------------------
Write-Host "4. タスクバーを左寄せにし、ボタン (検索, タスクビュー, ウィジェット, チャット) を非表示にします..." -ForegroundColor Yellow
$TaskbarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# 4-1. タスクバーの配置を左に変更 (0: 左寄せ)
Set-ItemProperty -Path $TaskbarPath -Name "TaskbarAl" -Type DWord -Value 0

# 4-2. タスクビューを無効化 (0: 非表示)
Set-ItemProperty -Path $TaskbarPath -Name "ShowTaskViewButton" -Type DWord -Value 0

# 4-3. ウィジェットを無効化 (0: 非表示)
Set-ItemProperty -Path $TaskbarPath -Name "TaskbarDa" -Type DWord -Value 0

# 4-4. チャット (Teams) を非表示 (0: 非表示)
Set-ItemProperty -Path $TaskbarPath -Name "TaskbarMn" -Type DWord -Value 0

# 4-5. 検索アイコンを非表示 (0: 非表示)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 0

Write-Host "   -> タスクバーのカスタマイズ設定が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 5. ダークモードに設定
# ----------------------------------------------------
Write-Host "5. ダークモードに設定します..." -ForegroundColor Yellow
$ThemePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
# アプリのテーマをダークモード (0) に設定
Set-ItemProperty -Path $ThemePath -Name "AppsUseLightTheme" -Value 0 -Type DWord
# システムのテーマをダークモード (0) に設定
Set-ItemProperty -Path $ThemePath -Name "SystemUsesLightTheme" -Value 0 -Type DWord
Write-Host "   -> ダークモードの設定が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 6. 隠しファイルの表示
# ----------------------------------------------------
Write-Host "6. 隠しファイルの表示を有効にします..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 1
Write-Host "   -> 隠しファイルの表示設定が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 7. ファイルの拡張子の表示
# ----------------------------------------------------
Write-Host "7. ファイルの拡張子の表示を有効にします..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideExt" -Type DWord -Value 0
Write-Host "   -> ファイルの拡張子の表示設定が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 8. エクスプローラーにフルパスを表示
# ----------------------------------------------------
Write-Host "8. エクスプローラーのタイトルバーにフルパスを表示します..." -ForegroundColor Yellow
# FullPath を 1 に設定 (1: 表示)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name "FullPath" -Type DWord -Value 1
Write-Host "   -> エクスプローラーのフルパス表示設定が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 9. Thumbs.dbの作成を無効化 (ネットワークフォルダのみ)
# ----------------------------------------------------
Write-Host "9. ネットワークフォルダでの Thumbs.db 作成を無効化します..." -ForegroundColor Yellow
# DisableThumbnailsOnNetworkFolders を 1 に設定 (1: 無効化)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "DisableThumbnailsOnNetworkFolders" -Type DWord -Value 1
Write-Host "   -> Thumbs.db 作成の無効化設定が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 10. ウインドウのスナップ関連機能の無効化
# ----------------------------------------------------
Write-Host "10. ウインドウのスナップ関連機能を無効化します..." -ForegroundColor Yellow
$SnapPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# スナップアシスト無効化 (0: 無効)
Set-ItemProperty -Path $SnapPath -Name "SnapAssist" -Type DWord -Value 0

# スナップアシストのフライアウト (提案機能) 無効化 (0: 無効)
Set-ItemProperty -Path $SnapPath -Name "EnableSnapAssistFlyout" -Type DWord -Value 0

# DITest 無効化 (0: 無効)
Set-ItemProperty -Path $SnapPath -Name "DITest" -Type DWord -Value 0

Write-Host "   -> ウインドウのスナップ関連機能の無効化が完了しました。" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------
# 設定の反映
# ----------------------------------------------------
Write-Host "設定を反映するためにエクスプローラーを再起動します (推奨)..." -ForegroundColor Blue
# エクスプローラーのプロセスを強制終了し、再起動させる
Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process "explorer"
Write-Host "エクスプローラーの再起動が完了しました。設定の多くは反映されています。" -ForegroundColor Blue

# ----------------------------------------------------
# 完了
# ----------------------------------------------------
Write-Host "`nすべての設定が完了しました。一部の設定はシステムの再起動後に完全に反映されます。" -ForegroundColor Cyan
