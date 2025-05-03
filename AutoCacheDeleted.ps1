Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
$console = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($console, 5)  # 5 = SW_SHOW

shutdown /a
Write-Host "=== SYSTEM SHUTDOWN CACHE CLEANER ===" -ForegroundColor Cyan

function Clear-TempWithTracking {
    param (
        [string]$DirectoryPath
    )
    
    $initialCount = @(Get-ChildItem -Path $DirectoryPath -Recurse -Force -ErrorAction SilentlyContinue).Count
    
    if ($initialCount -eq 0) {
        Write-Host "Directory $DirectoryPath is already empty" -ForegroundColor Yellow
        return $true
    }

    Write-Host "Deleting $initialCount files from $DirectoryPath..."
    
    $job = Start-Job -ScriptBlock {
        param($path)
        Get-ChildItem -Path $path -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } -ArgumentList $DirectoryPath

    do {
        $currentCount = @(Get-ChildItem -Path $DirectoryPath -Recurse -Force -ErrorAction SilentlyContinue).Count
        $remaining = $initialCount - $currentCount
        
        $percentComplete = if ($initialCount -gt 0) {
            [math]::Min(100, [math]::Max(0, ($remaining / $initialCount * 100)))
        } else {
            100
        }

        Write-Progress -Activity "Deleting files" `
                      -Status "Remaining: $currentCount files ($remaining of $initialCount processed)" `
                      -PercentComplete $percentComplete
        
        if ($currentCount -eq 0) {
            Write-Host "All files deleted successfully" -ForegroundColor Green
            return $true
        }
        
        Start-Sleep -Milliseconds 500
    } while ($job.State -eq 'Running')

    return ($currentCount -eq 0)
}

$tempPaths = @(
    "$env:TEMP", # Временные файлы пользователя
    
    "C:\Windows\Temp", # Временные файлы системы
    
    "C:\Windows\Prefetch", # Данные для оптимизации запуска программ
    
    "C:\Windows\SoftwareDistribution\Download", # Кеш загрузки центра обновлений windows
    
    "C:\ProgramData\Microsoft\Windows\WER", # Файлы отчетов об ошибке
    
    "$env:LOCALAPPDATA\Microsoft\Windows\DeliveryOptimization", # Кеш оптимизации доставки
    
    "C:\ProgramData\Microsoft\Windows Defender\Scans\History", # История сканирования защитником windows
    
    "$env:LOCALAPPDATA\Microsoft\Windows\FontCache", # Кеш шрифтов
    
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" # Интернет кеш (IE/Edge legacy)
    
)

$allCleared = $true

foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        Write-Host "`nProcessing directory: $path"
        if (-not (Clear-TempWithTracking -DirectoryPath $path)) {
            $allCleared = $false
        }
    } else {
        Write-Host "`nDirectory $path does not exist"
    }
}

if ($allCleared) {
    Write-Host "`nAll temp directories cleaned successfully"
} else {
    Write-Host "`nSome files could not be deleted (may be in use by system)"
}

shutdown /s /t 1
