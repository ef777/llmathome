#!/bin/bash
# setup_scripts.sh - Ubuntu sunucu yardımcı script'lerini oluştur

PROJECT_DIR="/var/www/kodlama-asistani"
cd "$PROJECT_DIR"

echo "🔧 Ubuntu Sunucu Yardımcı Script'leri Oluşturuluyor..."
echo "===================================================="

# monitor.sh
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "📊 Kodlama Asistanı - Canlı İzleme"
echo "=================================="
echo "Çıkmak için Ctrl+C basın"
echo ""

while true; do
    clear
    echo "🕐 $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================="
    
    # Servis durumları
    echo "🔧 SERVİSLER:"
    systemctl is-active --quiet kodlama-asistani && echo "  ✅ Flask Server: Aktif" || echo "  ❌ Flask Server: İnaktif"
    systemctl is-active --quiet nginx && echo "  ✅ Nginx: Aktif" || echo "  ❌ Nginx: İnaktif"
    
    # Port durumları
    echo "🔌 PORTLAR:"
    netstat -tuln | grep -q ":5000" && echo "  ✅ 5000 (Flask)" || echo "  ❌ 5000 (Flask)"
    netstat -tuln | grep -q ":8765" && echo "  ✅ 8765 (WebSocket)" || echo "  ❌ 8765 (WebSocket)" 
    netstat -tuln | grep -q ":80" && echo "  ✅ 80 (HTTP)" || echo "  ❌ 80 (HTTP)"
    
    # Sistem kaynakları
    echo "💾 SİSTEM KAYNAKLARI:"
    echo "  CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
    echo "  RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2 " (" int($3/$2 * 100) "%)"}')"
    echo "  Disk: $(df -h / | awk '/\// {print $3 "/" $2 " (" $5 ")"}')"
    
    # Bağlantı sayıları
    echo "🌐 BAĞLANTILAR:"
    HTTP_CONN=$(netstat -an | grep ":80" | grep ESTABLISHED | wc -l)
    WEBSOCKET_CONN=$(netstat -an | grep ":8765" | grep ESTABLISHED | wc -l)
    echo "  HTTP: $HTTP_CONN aktif bağlantı"
    echo "  WebSocket: $WEBSOCKET_CONN aktif bağlantı"
    
    # Son istekler
    echo "📈 SON 1 DAKİKA:"
    RECENT_REQUESTS=$(sudo tail -n 1000 /var/log/nginx/access.log 2>/dev/null | grep "$(date -d '1 minute ago' +'%d/%b/%Y:%H:%M')" | wc -l)
    echo "  HTTP İstekleri: $RECENT_REQUESTS"
    
    # API health check
    if command -v curl &> /dev/null; then
        API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health 2>/dev/null)
        if [ "$API_STATUS" = "200" ]; then
            echo "  🟢 API Health: OK"
        else
            echo "  🔴 API Health: ERROR ($API_STATUS)"
        fi
    fi
    
    echo "=================================="
    echo "📱 Web Arayüzü: http://$(hostname -I | awk '{print $1}')"
    
    sleep 5
done
EOF

# backup.sh
cat > backup.sh << 'EOF'
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
sudo find /var/log/kodlama-asistani -name "*.log" -mtime -7 -exec cp {} "$BACKUP_DIR/" \; 2>/dev/null

# Yedekleme özeti
echo "✅ Yedekleme tamamlandı!"
echo "📂 Yedekleme dizini: $BACKUP_DIR"
echo "📦 Dosyalar:"
sudo ls -lah "$BACKUP_DIR/" | grep "$DATE"

# Eski yedekleri temizle (30 günden eski)
echo "🧹 Eski yedekler temizleniyor..."
sudo find "$BACKUP_DIR" -name "*" -mtime +30 -delete 2>/dev/null
echo "📊 Toplam yedekleme boyutu: $(sudo du -sh $BACKUP_DIR | cut -f1)"
EOF

# restore.sh
cat > restore.sh << 'EOF'
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
EOF

# update.sh  
cat > update.sh << 'EOF'
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
EOF

# security.sh
cat > security.sh << 'EOF'
#!/bin/bash
echo "🔒 Kodlama Asistanı Güvenlik Sıkılaştırma"
echo "========================================"

# Fail2ban kurulumu
echo "🛡️ Fail2ban kuruluyor..."
sudo apt update
sudo apt install -y fail2ban

# Fail2ban konfigürasyonu
sudo tee /etc/fail2ban/jail.local > /dev/null << 'FAIL2BAN_EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
FAIL2BAN_EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# UFW kurallarını sıkılaştır
echo "🔥 Firewall kuralları sıkılaştırılıyor..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Sadece gerekli portları aç
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Rate limiting
sudo ufw limit ssh

sudo ufw --force enable

echo "✅ Güvenlik sıkılaştırma tamamlandı!"
EOF

# test.sh
cat > test.sh << 'EOF'
#!/bin/bash
echo "🧪 Kodlama Asistanı Sistem Testleri"
echo "==================================="

PROJECT_DIR="/var/www/kodlama-asistani"
SERVER_IP=$(hostname -I | awk '{print $1}')
ERRORS=0

# Test fonksiyonu
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "🔍 $test_name... "
    if eval "$test_command" > /dev/null 2>&1; then
        echo "✅ BAŞARILI"
    else
        echo "❌ BAŞARISIZ"
        ((ERRORS++))
    fi
}

echo "🏁 Temel sistem testleri başlıyor..."

# Proje dizini kontrolü
run_test "Proje dizini kontrolü" "[ -d '$PROJECT_DIR' ]"

# Python sanal ortam kontrolü
run_test "Python sanal ortam" "[ -f '$PROJECT_DIR/venv/bin/activate' ]"

# Flask app dosyası kontrolü
run_test "Flask app dosyası" "[ -f '$PROJECT_DIR/app.py' ]"

# Web template kontrolü
run_test "Web template dosyası" "[ -f '$PROJECT_DIR/templates/index.html' ]"

# Python paketleri kontrolü
run_test "Python paketleri" "cd '$PROJECT_DIR' && source venv/bin/activate && python -c 'import flask, websockets, requests'"

# Systemd servis kontrolü
run_test "Systemd servis dosyası" "[ -f '/etc/systemd/system/kodlama-asistani.service' ]"

# Nginx konfigürasyon kontrolü
run_test "Nginx site konfigürasyonu" "[ -f '/etc/nginx/sites-available/kodlama-asistani' ]"

# Nginx konfigürasyon geçerliliği
run_test "Nginx konfigürasyon geçerliliği" "sudo nginx -t"

echo ""
echo "🚀 Servis testleri başlıyor..."

# Servis durumları
run_test "Flask servis durumu" "systemctl is-active --quiet kodlama-asistani"
run_test "Nginx servis durumu" "systemctl is-active --quiet nginx"

echo ""
echo "🔌 Port testleri başlıyor..."

# Port kontrolü
run_test "Port 5000 (Flask)" "netstat -tuln | grep -q ':5000'"
run_test "Port 8765 (WebSocket)" "netstat -tuln | grep -q ':8765'"
run_test "Port 80 (HTTP)" "netstat -tuln | grep -q ':80'"

echo ""
echo "🌐 HTTP testleri başlıyor..."

if command -v curl &> /dev/null; then
    # HTTP testleri
    run_test "Ana sayfa erişimi" "curl -f http://localhost/ > /dev/null"
    run_test "API health endpoint" "curl -f http://localhost/api/health > /dev/null"
    run_test "API status endpoint" "curl -f http://localhost/api/status > /dev/null"
    
    # WebSocket testi (basit)
    echo -n "🔍 WebSocket bağlantı testi... "
    if timeout 5 bash -c "echo > /dev/tcp/localhost/8765" 2>/dev/null; then
        echo "✅ BAŞARILI"
    else
        echo "❌ BAŞARISIZ"
        ((ERRORS++))
    fi
else
    echo "⚠️ curl komutu bulunamadı, HTTP testleri atlanıyor"
fi

echo ""
echo "📊 TEST SONUÇLARI"
echo "================="

if [ $ERRORS -eq 0 ]; then
    echo "🎉 TÜM TESTLER BAŞARILI!"
    echo "✅ Sistem tamamen çalışır durumda"
    echo ""
    echo "🌍 Erişim bilgileri:"
    echo "  📱 Web Arayüzü: http://$SERVER_IP"
    echo "  📊 API Status: http://$SERVER_IP/api/status"
    echo "  🏥 Health Check: http://$SERVER_IP/api/health"
else
    echo "⚠️ $ERRORS TEST BAŞARISIZ!"
    echo "🔧 Sorunları çözmek için:"
    echo "  📋 Logları kontrol edin: ./logs.sh"
    echo "  📊 Sistem durumunu kontrol edin: ./status.sh"
    echo "  🔄 Servisleri yeniden başlatın: ./restart.sh"
fi
EOF

# restart.sh
cat > restart.sh << 'EOF'
#!/bin/bash
echo "🔄 Kodlama Asistanı Servis Yeniden Başlatma"
echo "=========================================="

echo "🛑 Servisleri durduruyor..."
sudo systemctl stop kodlama-asistani
sudo systemctl stop nginx

echo "⏱️ 3 saniye bekleniyor..."
sleep 3

echo "▶️ Servisleri başlatıyor..."
sudo systemctl start kodlama-asistani
sudo systemctl start nginx

echo "⏱️ Stabilizasyon için 5 saniye bekleniyor..."
sleep 5

echo "📊 Servis durumları:"
if systemctl is-active --quiet kodlama-asistani; then
    echo "  ✅ Flask Server: Aktif"
else
    echo "  ❌ Flask Server: İnaktif"
    echo "    📋 Log: sudo journalctl -u kodlama-asistani --lines=10"
fi

if systemctl is-active --quiet nginx; then
    echo "  ✅ Nginx: Aktif"
else
    echo "  ❌ Nginx: İnaktif"
    echo "    📋 Log: sudo journalctl -u nginx --lines=10"
fi

echo ""
echo "🧪 Hızlı sistem testi..."
if curl -f http://localhost/api/health > /dev/null 2>&1; then
    echo "✅ Sistem çalışıyor!"
    echo "🌍 Erişim: http://$(hostname -I | awk '{print $1}')"
else
    echo "❌ Sistem testi başarısız!"
    echo "🔧 Sorun giderme: ./logs.sh"
fi
EOF

# Tüm script'leri executable yap
chmod +x *.sh

echo "✅ Tüm yardımcı script'ler oluşturuldu ve executable yapıldı!"
echo ""
echo "📋 Oluşturulan script'ler:"
echo "  📊 monitor.sh - Canlı sistem izleme"
echo "  💾 backup.sh - Sistem yedekleme"  
echo "  ♻️ restore.sh - Yedekten geri yükleme"
echo "  🔄 update.sh - Sistem güncelleme"
echo "  🔒 security.sh - Güvenlik sıkılaştırma"
echo "  🧪 test.sh - Kapsamlı sistem testleri"
echo "  🔄 restart.sh - Servis yeniden başlatma"
echo ""
echo "🚀 Kullanım: ./script_adı.sh"