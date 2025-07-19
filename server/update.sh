
# ==========================================
# update.sh - Güncelleme Script'i
# ==========================================

#!/bin/bash
echo "🔄 Kodlama Asistanı Güncelleme"
echo "============================="

PROJECT_DIR="/var/www/kodlama-asistani"
cd "$PROJECT_DIR"

# Yedekleme yap
echo "💾 Güncelleme öncesi yedekleme..."
./backup.sh

echo "🛑 Servisleri durduruyor..."
sudo systemctl stop kodlama-asistani

echo "🐍 Python paketleri güncelleniyor..."
source venv/bin/activate
pip install --upgrade pip
pip install --upgrade -r requirements.txt

echo "🌐 Sistem paketleri güncelleniyor..."
sudo apt update
sudo apt upgrade -y

echo "🔧 Nginx konfigürasyonu kontrol ediliyor..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx konfigürasyonu geçerli"
else
    echo "❌ Nginx konfigürasyonu hatası!"
    echo "🔄 Yedekten geri yükleniyor..."
    # Yedekten geri yükle
    exit 1
fi

echo "▶️ Servisleri başlatıyor..."
sudo systemctl start kodlama-asistani
sudo systemctl start nginx

echo "⏱️ Sistem stabilizasyonu bekleniyor..."
sleep 10

echo "🧪 Sistem testi yapılıyor..."
if curl -f http://localhost/api/health > /dev/null 2>&1; then
    echo "✅ Güncelleme başarılı!"
else
    echo "❌ Güncelleme sonrası sistem testi başarısız!"
    echo "📋 Logları kontrol edin: ./logs.sh"
fi

echo "📊 Güncel durum:"
./status.sh