#!/bin/bash
# restart.sh - Kodlama Asistanı Servis Yeniden Başlatma Script'i

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}🔄 Kodlama Asistanı Servis Yeniden Başlatma${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"

# Log restart işlemini
echo "$(date): Restart işlemi başladı" >> /var/log/kodlama-asistani/startup.log

echo ""
echo -e "${PURPLE}📊 Mevcut Durum Kontrolü${NC}"
echo -e "${CYAN}─────────────────────────${NC}"

# Mevcut durumu kontrol et
echo -n "  📱 Flask/WebSocket: "
if systemctl is-active --quiet kodlama-asistani; then
    echo -e "${GREEN}✅ Çalışıyor${NC}"
    FLASK_RUNNING=true
else
    echo -e "${RED}❌ Çalışmıyor${NC}"
    FLASK_RUNNING=false
fi

echo -n "  🌐 Nginx: "
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Çalışıyor${NC}"
    NGINX_RUNNING=true
else
    echo -e "${RED}❌ Çalışmıyor${NC}"
    NGINX_RUNNING=false
fi

# Port kontrolleri
echo -n "  🔌 Port 5000: "
if netstat -tuln | grep -q ":5000 "; then
    echo -e "${GREEN}✅ Açık${NC}"
else
    echo -e "${RED}❌ Kapalı${NC}"
fi

echo -n "  🔌 Port 8765: "
if netstat -tuln | grep -q ":8765 "; then
    echo -e "${GREEN}✅ Açık${NC}"
else
    echo -e "${RED}❌ Kapalı${NC}"
fi

echo -n "  🔌 Port 80: "
if netstat -tuln | grep -q ":80 "; then
    echo -e "${GREEN}✅ Açık${NC}"
else
    echo -e "${RED}❌ Kapalı${NC}"
fi

echo ""

# Durdurma işlemi
echo -e "${PURPLE}🛑 Servisleri Durduruyor${NC}"
echo -e "${CYAN}─────────────────────────${NC}"

echo -n "  📱 Flask/WebSocket durduruluyor... "
if sudo systemctl stop kodlama-asistani; then
    echo -e "${GREEN}✅ Durduruldu${NC}"
else
    echo -e "${RED}❌ Durdurulamadı${NC}"
fi

echo -n "  🌐 Nginx durduruluyor... "
if sudo systemctl stop nginx; then
    echo -e "${GREEN}✅ Durduruldu${NC}"
else
    echo -e "${RED}❌ Durdurulamadı${NC}"
fi

# Süreçlerin tamamen durması için bekle
echo -e "${BLUE}⏱️ Süreçlerin tamamen durması bekleniyor...${NC}"
sleep 3

# Kalan süreçleri kontrol et ve gerekirse zorla sonlandır
echo -e "${BLUE}🔍 Kalan süreçler kontrol ediliyor...${NC}"

REMAINING_GUNICORN=$(pgrep -f "gunicorn.*kodlama-asistani" | wc -l)
if [ "$REMAINING_GUNICORN" -gt 0 ]; then
    echo -e "  ⚠️ ${YELLOW}$REMAINING_GUNICORN Gunicorn süreci hala çalışıyor, zorla sonlandırılıyor...${NC}"
    sudo pkill -f "gunicorn.*kodlama-asistani"
    sleep 2
fi

REMAINING_NGINX=$(pgrep nginx | wc -l)
if [ "$REMAINING_NGINX" -gt 0 ] && ! systemctl is-active --quiet nginx; then
    echo -e "  ⚠️ ${YELLOW}$REMAINING_NGINX Nginx süreci hala çalışıyor, zorla sonlandırılıyor...${NC}"
    sudo pkill nginx
    sleep 2
fi

# Port kontrolü
echo -e "${BLUE}🔌 Portların serbest olması bekleniyor...${NC}"
for i in {1..10}; do
    if ! netstat -tuln | grep -q ":5000 \|:8765 \|:80 "; then
        echo -e "  ✅ ${GREEN}Tüm portlar serbest bırakıldı${NC}"
        break
    else
        echo -n "."
        sleep 1
    fi
    
    if [ "$i" -eq 10 ]; then
        echo -e "  ⚠️ ${YELLOW}Bazı portlar hala meşgul olabilir${NC}"
    fi
done

echo ""

# Sistem durumunu temizle
echo -e "${PURPLE}🧹 Sistem Temizliği${NC}"
echo -e "${CYAN}─────────────────${NC}"

echo -n "  🔄 Systemd durumları sıfırlanıyor... "
sudo systemctl reset-failed kodlama-asistani 2>/dev/null
sudo systemctl reset-failed nginx 2>/dev/null
echo -e "${GREEN}✅ Sıfırlandı${NC}"

# Konfigürasyon dosyalarını kontrol et
echo -n "  ⚙️ Konfigürasyon dosyaları kontrol ediliyor... "
if [ -f "/var/www/kodlama-asistani/app.py" ] && [ -f "/var/www/kodlama-asistani/gunicorn.conf.py" ]; then
    echo -e "${GREEN}✅ Tamam${NC}"
else
    echo -e "${RED}❌ Eksik dosyalar var${NC}"
fi

# Nginx konfigürasyonu test et
echo -n "  🌐 Nginx konfigürasyonu test ediliyor... "
if sudo nginx -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Geçerli${NC}"
else
    echo -e "${RED}❌ Hatalı${NC}"
    echo -e "    ${YELLOW}Nginx konfigürasyon hatası, yine de devam ediliyor...${NC}"
fi

# Log dosyalarının erişilebilirliğini kontrol et
echo -n "  📋 Log dizinleri kontrol ediliyor... "
if [ -d "/var/log/kodlama-asistani" ] && [ -w "/var/log/kodlama-asistani" ]; then
    echo -e "${GREEN}✅ Erişilebilir${NC}"
else
    echo -e "${YELLOW}⚠️ Log dizini oluşturuluyor...${NC}"
    sudo mkdir -p /var/log/kodlama-asistani
    sudo chown $USER:$USER /var/log/kodlama-asistani
fi

echo ""

# Başlatma işlemi
echo -e "${PURPLE}🚀 Servisleri Başlatıyor${NC}"
echo -e "${CYAN}─────────────────────────${NC}"

echo -n "  📱 Flask/WebSocket başlatılıyor... "
if sudo systemctl start kodlama-asistani; then
    echo -e "${GREEN}✅ Başlatıldı${NC}"
    FLASK_START_SUCCESS=true
else
    echo -e "${RED}❌ Başlatılamadı${NC}"
    FLASK_START_SUCCESS=false
    echo -e "    ${YELLOW}Log: sudo journalctl -u kodlama-asistani --lines=10${NC}"
fi

echo -n "  🌐 Nginx başlatılıyor... "
if sudo systemctl start nginx; then
    echo -e "${GREEN}✅ Başlatıldı${NC}"
    NGINX_START_SUCCESS=true
else
    echo -e "${RED}❌ Başlatılamadı${NC}"
    NGINX_START_SUCCESS=false
    echo -e "    ${YELLOW}Log: sudo journalctl -u nginx --lines=10${NC}"
fi

# Servislerin stabilizasyonu için bekle
echo -e "${BLUE}⏱️ Servislerin stabilizasyonu bekleniyor...${NC}"
for i in {1..10}; do
    echo -n "."
    sleep 1
done
echo ""

echo ""

# Yeni durum kontrolü
echo -e "${PURPLE}📊 Yeniden Başlatma Sonrası Durum${NC}"
echo -e "${CYAN}──────────────────────────────────${NC}"

# Servis durumları
echo -n "  📱 Flask/WebSocket: "
if systemctl is-active --quiet kodlama-asistani; then
    echo -e "${GREEN}✅ Çalışıyor${NC}"
    FLASK_FINAL=true
else
    echo -e "${RED}❌ Çalışmıyor${NC}"
    FLASK_FINAL=false
fi

echo -n "  🌐 Nginx: "
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Çalışıyor${NC}"
    NGINX_FINAL=true
else
    echo -e "${RED}❌ Çalışmıyor${NC}"
    NGINX_FINAL=false
fi

# Port kontrolleri
echo "  🔌 Port Durumları:"
for port in "5000:Flask" "8765:WebSocket" "80:HTTP"; do
    port_num=$(echo $port | cut -d: -f1)
    port_name=$(echo $port | cut -d: -f2)
    
    echo -n "    Port $port_num ($port_name): "
    if netstat -tuln | grep -q ":$port_num "; then
        echo -e "${GREEN}✅ Açık${NC}"
    else
        echo -e "${RED}❌ Kapalı${NC}"
    fi
done

echo ""

# Hızlı sistem testleri
echo -e "${PURPLE}🧪 Hızlı Sistem Testleri${NC}"
echo -e "${CYAN}─────────────────────────${NC}"

# API health check
echo -n "  🏥 API Health Check: "
if curl -f -s http://localhost/api/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Başarılı${NC}"
    API_TEST=true
else
    echo -e "${RED}❌ Başarısız${NC}"
    API_TEST=false
fi

# Ana sayfa testi
echo -n "  🌐 Ana Sayfa Testi: "
if curl -f -s http://localhost/ >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Başarılı${NC}"
    WEB_TEST=true
else
    echo -e "${RED}❌ Başarısız${NC}"
    WEB_TEST=false
fi

# WebSocket port testi
echo -n "  🔌 WebSocket Port Testi: "
if timeout 3 bash -c "echo > /dev/tcp/localhost/8765" 2>/dev/null; then
    echo -e "${GREEN}✅ Başarılı${NC}"
    WS_TEST=true
else
    echo -e "${RED}❌ Başarısız${NC}"
    WS_TEST=false
fi

echo ""

# Sistem kaynakları
echo -e "${PURPLE}💾 Sistem Kaynakları${NC}"
echo -e "${CYAN}──────────────────${NC}"

CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
RAM_INFO=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ')

echo -e "  🖥️ CPU Kullanımı: ${YELLOW}$CPU_USAGE${NC}"
echo -e "  🧠 RAM Kullanımı: ${YELLOW}$RAM_INFO${NC}"
echo -e "  ⚖️ Sistem Yükü: ${YELLOW}$LOAD_AVG${NC}"

echo ""

# Genel durum özeti
echo -e "${PURPLE}📋 RESTART SONUÇLARI${NC}"
echo -e "${CYAN}════════════════════${NC}"

if [ "$FLASK_FINAL" = true ] && [ "$NGINX_FINAL" = true ] && [ "$API_TEST" = true ] && [ "$WEB_TEST" = true ]; then
    echo -e "${GREEN}🎉 RESTART TAMAMEN BAŞARILI!${NC}"
    echo -e "${GREEN}✅ Tüm servisler normal çalışıyor${NC}"
    echo ""
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo -e "${CYAN}🌍 Erişim Adresleri:${NC}"
    echo -e "  📱 Web Arayüzü: ${GREEN}http://$SERVER_IP${NC}"
    echo -e "  📊 API Status: ${BLUE}http://$SERVER_IP/api/status${NC}"
    echo -e "  🏥 Health Check: ${BLUE}http://$SERVER_IP/api/health${NC}"
    
    # Log başarı durumu
    echo "$(date): Restart başarılı - Tüm servisler çalışıyor" >> /var/log/kodlama-asistani/startup.log
    
elif [ "$FLASK_FINAL" = true ] && [ "$NGINX_FINAL" = true ]; then
    echo -e "${YELLOW}⚠️ RESTART KISMEN BAŞARILI${NC}"
    echo -e "${YELLOW}🔧 Servisler çalışıyor ama bazı testler başarısız${NC}"
    echo ""
    echo -e "${BLUE}🔍 Detaylı kontrol için:${NC}"
    echo -e "  ${BLUE}./status.sh${NC} - Sistem durumu"
    echo -e "  ${BLUE}./logs.sh${NC} - Detaylı loglar"
    
    # Log kısmi başarı
    echo "$(date): Restart kısmen başarılı - Bazı testler başarısız" >> /var/log/kodlama-asistani/startup.log
    
else
    echo -e "${RED}❌ RESTART BAŞARISIZ!${NC}"
    echo -e "${RED}🔧 Kritik servisler başlatılamadı${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Sorun giderme adımları:${NC}"
    
    if [ "$FLASK_FINAL" = false ]; then
        echo -e "  ${RED}Flask servisi:${NC}"
        echo -e "    ${BLUE}sudo journalctl -u kodlama-asistani --lines=20${NC}"
        echo -e "    ${BLUE}sudo systemctl status kodlama-asistani${NC}"
    fi
    
    if [ "$NGINX_FINAL" = false ]; then
        echo -e "  ${RED}Nginx servisi:${NC}"
        echo -e "    ${BLUE}sudo nginx -t${NC}"
        echo -e "    ${BLUE}sudo journalctl -u nginx --lines=20${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📋 Detaylı bilgi için:${NC}"
    echo -e "  ${BLUE}./logs.sh errors${NC} - Hata logları"
    echo -e "  ${BLUE}./test.sh${NC} - Kapsamlı test"
    
    # Log hata durumu
    echo "$(date): Restart başarısız - Kritik hatalar var" >> /var/log/kodlama-asistani/startup.log
fi

echo ""

# Hızlı komutlar
echo -e "${PURPLE}🎮 Kullanılabilir Komutlar${NC}"
echo -e "${CYAN}─────────────────────────${NC}"
echo -e "  ${BLUE}./status.sh${NC} - Detaylı sistem durumu"
echo -e "  ${BLUE}./logs.sh${NC} - Sistem loglarını görüntüle"
echo -e "  ${BLUE}./test.sh${NC} - Kapsamlı sistem testi"
echo -e "  ${BLUE}./start_server.sh${NC} - Manuel başlatma"
echo -e "  ${BLUE}./stop_server.sh${NC} - Manuel durdurma"

echo ""

# Performans önerileri (eğere sorun varsa)
if [ "$FLASK_FINAL" = false ] || [ "$NGINX_FINAL" = false ] || [ "$API_TEST" = false ]; then
    echo -e "${YELLOW}💡 PERFORMANS ÖNERİLERİ${NC}"
    echo -e "${CYAN}──────────────────────${NC}"
    echo -e "  🔄 Manuel restart: ${BLUE}sudo systemctl restart kodlama-asistani${NC}"
    echo -e "  🧹 Cache temizliği: ${BLUE}sudo systemctl daemon-reload${NC}"
    echo -e "  💾 Disk alanı: ${BLUE}df -h${NC}"
    echo -e "  🧠 Bellek durumu: ${BLUE}free -h${NC}"
    echo ""
fi

echo -e "${GREEN}🔄 Restart işlemi tamamlandı!${NC}"

# Exit code - başarısızlık durumunda 1 döndür
if [ "$FLASK_FINAL" = false ] || [ "$NGINX_FINAL" = false ]; then
    exit 1
fi

exit 0