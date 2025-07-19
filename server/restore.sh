# ==========================================
# restore.sh - Geri Yükleme Script'i
# ==========================================

#!/bin/bash
echo "♻️ Kodlama Asistanı Geri Yükleme"
echo "==============================="

BACKUP_DIR="/var/backups/kodlama-asistani"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Yedekleme dizini bulunamadı: $BACKUP_DIR"
    exit 1
fi

echo "📋 Mevcut yedeklemeler:"
sudo ls -la "$BACKUP_DIR/"/*.tar.gz 2>/dev/null || {
    echo "❌ Yedekleme dosyası bulunamadı!"
    exit 1
}

echo ""
read -p "🔍 Geri yüklemek istediğiniz dosya adını girin: " BACKUP_FILE

if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "❌ Yedekleme dosyası bulunamadı: $BACKUP_FILE"
    exit 1
fi

echo "⚠️ Bu işlem mevcut dosyaları üzerine yazacak!"
read -p "🤔 Devam etmek istiyor musunuz? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo "🛑 Servisleri durduruyor..."
sudo systemctl stop kodlama-asistani
sudo systemctl stop nginx

echo "♻️ Dosyalar geri yükleniyor..."
cd /var/www/kodlama-asistani
sudo tar -xzf "$BACKUP_DIR/$BACKUP_FILE"

echo "🔧 İzinler ayarlanıyor..."
sudo chown -R $USER:$USER /var/www/kodlama-asistani

echo "▶️ Servisler başlatılıyor..."
sudo systemctl start kodlama-asistani
sudo systemctl start nginx

echo "✅ Geri yükleme tamamlandı!"
echo "📊 Durum kontrolü yapılıyor..."
sleep 3
./status.sh
