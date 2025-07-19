
# ==========================================
# backup.sh - Yedekleme Script'i
# ==========================================

#!/bin/bash
echo "💾 Kodlama Asistanı Yedekleme"
echo "============================="

BACKUP_DIR="/var/backups/kodlama-asistani"
DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/var/www/kodlama-asistani"

# Yedekleme dizini oluştur
sudo mkdir -p "$BACKUP_DIR"

echo "📦 Yedekleme başlıyor..."

# Proje dosyalarını yedekle
echo "📂 Proje dosyaları yedekleniyor..."
sudo tar -czf "$BACKUP_DIR/project_$DATE.tar.gz" -C "$PROJECT_DIR" .

# Nginx konfigürasyonu
echo "🌐 Nginx konfigürasyonu yedekleniyor..."
sudo cp /etc/nginx/sites-available/kodlama-asistani "$BACKUP_DIR/nginx_config_$DATE"

# Systemd servisi
echo "🔧 Systemd servisi yedekleniyor..."
sudo cp /etc/systemd/system/kodlama-asistani.service "$BACKUP_DIR/systemd_service_$DATE"

# Logları yedekle (son 7 gün)
echo "📋 Loglar yedekleniyor..."
sudo find /var/log/kodlama-asistani -name "*.log" -mtime -7 -exec cp {} "$BACKUP_DIR/" \;

# Yedekleme özeti
echo "✅ Yedekleme tamamlandı!"
echo "📂 Yedekleme dizini: $BACKUP_DIR"
echo "📦 Dosyalar:"
sudo ls -lah "$BACKUP_DIR/" | grep "$DATE"

# Eski yedekleri temizle (30 günden eski)
echo "🧹 Eski yedekler temizleniyor..."
sudo find "$BACKUP_DIR" -name "*" -mtime +30 -delete
echo "📊 Toplam yedekleme boyutu: $(sudo du -sh $BACKUP_DIR | cut -f1)"