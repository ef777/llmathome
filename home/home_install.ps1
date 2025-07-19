# install.ps1 - Windows Kodlama Asistanı Kurulum Script'i
# Bu script'i Administrator olarak çalıştırın!

Write-Host "🤖 Kodlama Asistanı - Windows Kurulumu" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Renkli yazdırma fonksiyonları
function Write-Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor Blue
}

function Write-Success($message) {
    Write-Host "[SUCCESS] $message" -ForegroundColor Green
}

function Write-Warning($message) {
    Write-Host "[WARNING] $message" -ForegroundColor Yellow
}

function Write-Error($message) {
    Write-Host "[ERROR] $message" -ForegroundColor Red
}

# Administrator kontrolü
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Bu script'i Administrator olarak çalıştırmanız gerekiyor!"
    Write-Host "PowerShell'i sağ tıklayıp 'Run as Administrator' seçin."
    Read-Host "Devam etmek için Enter'a basın"
    exit 1
}

# 1. NVIDIA GPU kontrolü
Write-Info "NVIDIA GPU kontrolü yapılıyor..."
try {
    $gpuInfo = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>$null
    if ($gpuInfo) {
        Write-Success "NVIDIA GPU tespit edildi: $gpuInfo"
    } else {
        Write-Error "nvidia-smi komutu çalışmıyor. NVIDIA sürücüleri kurulu mu?"
        Read-Host "Devam etmek için Enter'a basın"
    }
} catch {
    Write-Warning "GPU kontrolü başarısız. Devam ediliyor..."
}

# 2. Python kontrolü ve kurulumu
Write-Info "Python kontrolü yapılıyor..."
$pythonVersion = python --version 2>$null
if ($pythonVersion) {
    Write-Success "Python mevcut: $pythonVersion"
} else {
    Write-Info "Python kuruluyor..."
    $pythonUrl = "https://www.python.org/ftp/python/3.11.7/python-3.11.7-amd64.exe"
    $pythonInstaller = "$env:TEMP\python-installer.exe"
    
    Write-Info "Python indiriliyor..."
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
    
    Write-Info "Python kuruluyor... (Bu biraz zaman alabilir)"
    Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait
    
    # PATH'i yenile
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Remove-Item $pythonInstaller -Force
    Write-Success "Python kuruldu!"
}

# 3. Git kontrolü (Ollama için gerekli)
Write-Info "Git kontrolü yapılıyor..."
$gitVersion = git --version 2>$null
if (-not $gitVersion) {
    Write-Info "Git kuruluyor..."
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
    $gitInstaller = "$env:TEMP\git-installer.exe"
    
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
    Remove-Item $gitInstaller -Force
    
    # PATH'i yenile
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Success "Git kuruldu!"
}

# 4. Proje dizini oluştur
Write-Info "Proje dizini oluşturuluyor..."
$projectDir = "$env:USERPROFILE\kodlama-asistani"
if (-not (Test-Path $projectDir)) {
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
}
Set-Location $projectDir
Write-Success "Proje dizini: $projectDir"

# 5. Python sanal ortam oluştur
Write-Info "Python sanal ortam oluşturuluyor..."
python -m venv venv
if (Test-Path "venv\Scripts\activate.bat") {
    Write-Success "Sanal ortam oluşturuldu!"
} else {
    Write-Error "Sanal ortam oluşturulamadı!"
    exit 1
}

# 6. Python paketlerini yükle
Write-Info "Python paketleri yükleniyor..."
@"
flask==2.3.3
websockets==11.0.3
requests==2.31.0
colorama==0.4.6
asyncio==3.4.3
"@ | Out-File -FilePath "requirements.txt" -Encoding UTF8

& "venv\Scripts\pip.exe" install -r requirements.txt
Write-Success "Python paketleri yüklendi!"

# 7. Ollama kurulumu
Write-Info "Ollama kuruluyor..."
$ollamaPath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
if (-not (Test-Path $ollamaPath)) {
    $ollamaUrl = "https://ollama.ai/download/OllamaSetup.exe"
    $ollamaInstaller = "$env:TEMP\OllamaSetup.exe"
    
    Write-Info "Ollama indiriliyor..."
    Invoke-WebRequest -Uri $ollamaUrl -OutFile $ollamaInstaller
    
    Write-Info "Ollama kuruluyor..."
    Start-Process -FilePath $ollamaInstaller -ArgumentList "/S" -Wait
    Remove-Item $ollamaInstaller -Force
    
    # Ollama'yı PATH'e ekle
    $ollamaDir = "$env:LOCALAPPDATA\Programs\Ollama"
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$ollamaDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$ollamaDir", "User")
    }
    
    Write-Success "Ollama kuruldu!"
} else {
    Write-Success "Ollama zaten kurulu!"
}

# PATH'i yenile
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 8. Ollama servisini başlat
Write-Info "Ollama servisi başlatılıyor..."
Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
Start-Sleep 5

# 9. Model indirme
Write-Info "LLM modeli indiriliyor... (Bu UZUN sürebilir - 3-4GB)"
Write-Warning "Bu işlem 10-30 dakika sürebilir, sabır gösterin!"

try {
    & ollama pull deepseek-coder:6.7b-instruct-q4_0
    Write-Success "Model başarıyla indirildi!"
} catch {
    Write-Warning "Model indirme başarısız, daha sonra deneyin: ollama pull deepseek-coder:6.7b-instruct-q4_0"
}

# 10. Windows Defender istisna ekleme
Write-Info "Windows Defender istisnası ekleniyor..."
try {
    Add-MpPreference -ExclusionPath $projectDir -ErrorAction SilentlyContinue
    Write-Success "Windows Defender istisnası eklendi"
} catch {
    Write-Warning "Windows Defender istisnası eklenemedi (Normal bir durum)"
}

# 11. Firewall kuralı (opsiyonel)
Write-Info "Firewall kuralı oluşturuluyor..."
try {
    New-NetFirewallRule -DisplayName "Kodlama Asistani - Ollama" -Direction Outbound -Protocol TCP -LocalPort 11434 -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Kodlama Asistani - WebSocket" -Direction Outbound -Protocol TCP -RemotePort 8765 -Action Allow -ErrorAction SilentlyContinue
    Write-Success "Firewall kuralları oluşturuldu"
} catch {
    Write-Warning "Firewall kuralları oluşturulamadı"
}

# 12. Masaüstü kısayolu oluştur
Write-Info "Masaüstü kısayolu oluşturuluyor..."
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("$env:USERPROFILE\Desktop\Kodlama Asistanı.lnk")
$shortcut.TargetPath = "$projectDir\start.bat"
$shortcut.WorkingDirectory = $projectDir
$shortcut.IconLocation = "shell32.dll,25"
$shortcut.Description = "Kodlama Asistanı - Ev Client"
$shortcut.Save()
Write-Success "Masaüstü kısayolu oluşturuldu!"

# 13. Kurulum tamamlandı!
Write-Host ""
Write-Success "🎉 Windows kurulumu tamamlandı!"
Write-Host "=================================" -ForegroundColor Green
Write-Host ""
Write-Host "📂 Proje dizini: $projectDir" -ForegroundColor Yellow
Write-Host "🔧 Konfigürasyon: $projectDir\config.py" -ForegroundColor Yellow
Write-Host "▶️ Başlatma: start.bat (veya masaüstü kısayolu)" -ForegroundColor Yellow
Write-Host "🧪 Test: test.bat" -ForegroundColor Yellow
Write-Host "🛑 Durdurma: stop.bat" -ForegroundColor Yellow
Write-Host ""
Write-Host "🚨 ÖNEMLİ ADIMLAR:" -ForegroundColor Red
Write-Host "1. config.py dosyasında SUNUCU_IP'yi düzenleyin!" -ForegroundColor Red
Write-Host "2. Yeni PowerShell penceresi açıp 'ollama serve' çalıştırın" -ForegroundColor Red
Write-Host "3. start.bat ile client'ı başlatın" -ForegroundColor Red
Write-Host "4. Sunucuda Flask server'ı çalıştırın" -ForegroundColor Red
Write-Host ""
Write-Host "📱 Web arayüzü: http://SUNUCU_IP_ADRESINIZ" -ForegroundColor Cyan
Write-Host ""

Read-Host "Devam etmek için Enter'a basın"