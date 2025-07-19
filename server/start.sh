#!/bin/bash
# start_server.sh - Kodlama Asistanı Sunucu Başlatma Script'i

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🌐 Kodlama Asistanı Sunucu Başlatılıyor...${NC}"
echo -e "${CYAN}========================================${NC}"

# Log başlangıç zamanı
echo "$(date): Sunucu başlatma işlemi başladı" >> /var/log/kodlama-asistani/startup.log

echo -e "${BLUE}🔄 Servisler başlatılıyor...${NC}"

# Flask + WebSocket servisi başlat
echo -n "  📱 Flask/WebSocket servisi... "
if sudo systemctl start kodlama-asistani; then
    echo -e "${GREEN}✅ Başlatıldı${NC}"
else
    echo -e "${RED}❌ Başlatılamadı${NC}"
    echo -e "${YELLOW}📋 Log: sudo journalctl -u kodlama-asistani --lines=10${NC}"
fi

# Nginx web server başlat
echo -n "  🌐 Nginx web server... "
if sudo systemctl start nginx; then
    echo -e "${GREEN}✅ Başlatıldı${NC}"
else
    echo -e "${RED}❌ Başlatılamadı${NC}"
    echo -e "${YELLOW}📋 Log: sudo journalctl -u nginx --lines=10${NC}"
fi

# Servis stabilizasyonu için bekle
echo -e "${BLUE}⏱️ Servislerin stabilizasyonu bekleniyor...${NC}"
sleep 5

echo ""
echo -e "${CYAN}📊 Servis Durumları:${NC}"

# Flask servis kontrol
if systemctl is-active --quiet kodlama-asistani; then
    echo -e "  ✅ ${GREEN}Flask server: Aktif${NC}"
    FLASK_STATUS="OK"
else
    echo -e "  ❌ ${RED}Flask server: İnaktif${NC}"
    echo -e "     ${YELLOW}📋 Detay: sudo journalctl -u kodlama-asistani --lines=10${NC}"
    FLASK_STATUS="ERROR"
fi

# Nginx servis kontrol
if systemctl is-active --quiet nginx; then
    echo -e "  ✅ ${GREEN}Nginx: Aktif${NC}"
    NGINX_STATUS="OK"
else
    echo -e "  ❌ ${RED}Nginx: İnaktif${NC}"
    echo -e "     ${YELLOW}📋 Detay: sudo journalctl -u nginx --lines=10${NC}"
    NGINX_STATUS="ERROR"
fi

echo ""
echo -e "${CYAN}🔌 Port Kontrolleri:${NC}"

# Port kontrolü fonksiyonu
check_port() {
    local port=$1
    local service=$2
    local emoji=$3
    
    if netstat -tuln | grep -q ":$port "; then
        echo -e "  ✅ ${GREEN}Port $port ($service): Açık${NC}"
        return 0
    else
        echo -e "  ❌ ${RED}Port $port ($service): Kapalı${NC}"
        return 1
    fi
}

# Port kontrolleri
check_port "5000" "Flask" "📱"
check_port "8765" "WebSocket" "🔌"
check_port "80" "HTTP" "🌐"

echo ""
echo -e "${CYAN}💾 Sistem Kaynakları:${NC}"

# CPU kullanımı
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
echo -e "  🖥️ CPU Kullanımı: ${YELLOW}$CPU_USAGE${NC}"

# RAM kullanımı
RAM_INFO=$(free -h | awk '/^Mem:/ {print $3 "/" $2 " (" int($3/$2 * 100) "%)"}')
echo -e "  🧠 RAM Kullanımı: ${YELLOW}$RAM_INFO${NC}"

# Disk kullanımı
DISK_INFO=$(df -h / | awk '/\// {print $3 "/" $2 " (" $5 ")"}')
echo -e "  💽 Disk Kullanımı: ${YELLOW}$DISK_INFO${NC}"

# Sistem yükü
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ')
echo -e "  ⚖️ Sistem Yükü: ${YELLOW}$LOAD_AVG${NC}"

echo ""
echo -e "${CYAN}🌍 Erişim Adresleri:${NC}"

# IP adresini al
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "  📱 ${GREEN}Web Arayüzü: http://$SERVER_IP${NC}"
echo -e "  📊 ${BLUE}API Status: http://$SERVER_IP/api/status${NC}"
echo -e "  🏥 ${BLUE}Health Check: http://$SERVER_IP/api/health${NC}"

# Dış IP varsa göster
EXTERNAL_IP=$(curl -s -m 5 ifconfig.me 2>/dev/null || echo "Tespit edilemedi")
if [ "$EXTERNAL_IP" != "Tespit edilemedi" ] && [ "$EXTERNAL_IP" != "$SERVER_IP" ]; then
    echo -e "  🌐 ${CYAN}Dış IP: http://$EXTERNAL_IP${NC}"
fi

echo ""
echo -e "${CYAN}📱 Telefon/Tablet Erişimi:${NC}"
echo -e "  ${GREEN}1.${NC} Telefonunuzun tarayıcısını açın"
echo -e "  ${GREEN}2.${NC} Adres çubuğuna şunu yazın: ${YELLOW}$SERVER_IP${NC}"
echo -e "  ${GREEN}3.${NC} Kodlama asistanınızı kullanmaya başlayın!"

echo ""
echo -e "${CYAN}🧪 Hızlı Sistem Testi:${NC}"

# API health check
echo -n "  🏥 API sağlık testi... "
if curl -f -s http://localhost/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Başarılı${NC}"
    API_STATUS="OK"
else
    echo -e "${RED}❌ Başarısız${NC}"
    API_STATUS="ERROR"
fi

# Ana sayfa testi
echo -n "  🌐 Ana sayfa testi... "
if curl -f -s http://localhost/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Başarılı${NC}"
    WEB_STATUS="OK"
else
    echo -e "${RED}❌ Başarısız${NC}"
    WEB_STATUS="ERROR"
fi

# WebSocket port testi
echo -n "  🔌 WebSocket port testi... "
if timeout 3 bash -c "echo > /dev/tcp/localhost/8765" 2>/dev/null; then
    echo -e "${GREEN}✅ Başarılı${NC}"
    WS_STATUS="OK"
else
    echo -e "${RED}❌ Başarısız${NC}"
    WS_STATUS="ERROR"
fi

echo ""

# Genel durum özeti
if [ "$FLASK_STATUS" = "OK" ] && [ "$NGINX_STATUS" = "OK" ] && [ "$API_STATUS" = "OK" ] && [ "$WEB_STATUS" = "OK" ]; then
    echo -e "${GREEN}🎉 TÜM SİSTEMLER NORMAL ÇALIŞIYOR!${NC}"
    echo -e "${GREEN}✅ Sunucu hazır, ev makinesinden bağlanabilirsiniz${NC}"
    
    # Log başarı durumu
    echo "$(date): Sunucu başarıyla başlatıldı - Tüm testler OK" >> /var/log/kodlama-asistani/startup.log
    
    # Başarı sesi (eğer speaker varsa)
    echo -e "\a"
    
elif [ "$FLASK_STATUS" = "OK" ] && [ "$NGINX_STATUS" = "OK" ]; then
    echo -e "${YELLOW}⚠️ SİSTEM KISMEN ÇALIŞIYOR${NC}"
    echo -e "${YELLOW}🔧 Bazı testler başarısız, ancak temel servisler çalışıyor${NC}"
    
    # Log kısmi başarı
    echo "$(date): Sunucu kısmen başlatıldı - Bazı testler başarısız" >> /var/log/kodlama-asistani/startup.log
    
else
    echo -e "${RED}❌ SİSTEMDE SORUNLAR VAR!${NC}"
    echo -e "${RED}🔧 Aşağıdaki komutlarla sorunları giderin:${NC}"
    echo -e "  ${YELLOW}📋 ./logs.sh${NC} - Detaylı logları görün"
    echo -e "  ${YELLOW}📊 ./status.sh${NC} - Sistem durumunu kontrol edin"
    echo -e "  ${YELLOW}🔄 ./restart.sh${NC} - Servisleri yeniden başlatın"
    
    # Log hata durumu
    echo "$(date): Sunucu başlatma başarısız - Kritik servisler çalışmıyor" >> /var/log/kodlama-asistani/startup.log
fi

echo ""
echo -e "${CYAN}📋 Diğer Komutlar:${NC}"
echo -e "  ${BLUE}./stop_server.sh${NC} - Sunucuyu durdur"
echo -e "  ${BLUE}./restart.sh${NC} - Servisleri yeniden başlat"
echo -e "  ${BLUE}./status.sh${NC} - Detaylı sistem durumu"
echo -e "  ${BLUE}./logs.sh${NC} - Sistem loglarını görüntüle"
echo -e "  ${BLUE}./test.sh${NC} - Kapsamlı sistem testi"

echo ""
echo -e "${GREEN}🚀 Sunucu başlatma işlemi tamamlandı!${NC}"

# Eğer sistemde sorun varsa exit code 1 döndür
if [ "$FLASK_STATUS" != "OK" ] || [ "$NGINX_STATUS" != "OK" ]; then
    exit 1
fi

exit 0