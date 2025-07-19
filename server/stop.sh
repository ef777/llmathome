#!/bin/bash
# stop_server.sh - Kodlama Asistanı Sunucu Durdurma Script'i

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🛑 Kodlama Asistanı Sunucu Durduruluyor...${NC}"
echo -e "${CYAN}========================================${NC}"

# Log durdurma zamanı
echo "$(date): Sunucu durdurma işlemi başladı" >> /var/log/kodlama-asistani/startup.log

echo -e "${BLUE}🔄 Servisler durduruluyor...${NC}"

# Flask + WebSocket servisi durdur
echo -n "  📱 Flask/WebSocket servisi... "
if sudo systemctl stop kodlama-asistani; then
    echo -e "${GREEN}✅ Durduruldu${NC}"
    FLASK_STOP="OK"
else
    echo -e "${RED}❌ Durdurulamadı${NC}"
    FLASK_STOP="ERROR"
fi

# Nginx web server durdur
echo -n "  🌐 Nginx web server... "
if sudo systemctl stop nginx; then
    echo -e "${GREEN}✅ Durduruldu${NC}"
    NGINX_STOP="OK"
else
    echo -e "${RED}❌ Durdurulamadı${NC}"
    NGINX_STOP="ERROR"
fi

# Servislerin durması için bekle
echo -e "${BLUE}⏱️ Servislerin durması bekleniyor...${NC}"
sleep 3

echo ""
echo -e "${CYAN}📊 Durum Kontrolü:${NC}"

# Flask servis kontrol
echo -n "  📱 Flask server durumu... "
if systemctl is-active --quiet kodlama-asistani; then
    echo -e "${RED}⚠️ Hala çalışıyor${NC}"
    echo -e "     ${YELLOW}🔧 Zorla durdurmak için: sudo systemctl kill kodlama-asistani${NC}"
    FLASK_STATUS="RUNNING"
else
    echo -e "${GREEN}✅ Durduruldu${NC}"
    FLASK_STATUS="STOPPED"
fi

# Nginx servis kontrol
echo -n "  🌐 Nginx durumu... "
if systemctl is-active --quiet nginx; then
    echo -e "${RED}⚠️ Hala çalışıyor${NC}"
    echo -e "     ${YELLOW}🔧 Zorla durdurmak için: sudo systemctl kill nginx${NC}"
    NGINX_STATUS="RUNNING"
else
    echo -e "${GREEN}✅ Durduruldu${NC}"
    NGINX_STATUS="STOPPED"
fi

echo ""
echo -e "${CYAN}🔌 Port Kontrolleri:${NC}"

# Port kontrolü fonksiyonu
check_port_stopped() {
    local port=$1
    local service=$2
    
    if netstat -tuln | grep -q ":$port "; then
        echo -e "  ⚠️ ${YELLOW}Port $port ($service): Hala açık${NC}"
        return 1
    else
        echo -e "  ✅ ${GREEN}Port $port ($service): Kapalı${NC}"
        return 0
    fi
}

# Port kontrolleri
check_port_stopped "5000" "Flask"
check_port_stopped "8765" "WebSocket"
check_port_stopped "80" "HTTP"

echo ""
echo -e "${CYAN}🔍 Süreç Kontrolleri:${NC}"

# Python süreçlerini kontrol et
PYTHON_PROCS=$(pgrep -f "gunicorn.*kodlama-asistani" | wc -l)
if [ "$PYTHON_PROCS" -gt 0 ]; then
    echo -e "  ⚠️ ${YELLOW}$PYTHON_PROCS Python/Gunicorn süreci hala çalışıyor${NC}"
    echo -e "     ${YELLOW}🔧 Zorla sonlandırmak için: pkill -f 'gunicorn.*kodlama-asistani'${NC}"
else
    echo -e "  ✅ ${GREEN}Python/Gunicorn süreçleri temizlendi${NC}"
fi

# Nginx süreçlerini kontrol et
NGINX_PROCS=$(pgrep nginx | wc -l)
if [ "$NGINX_PROCS" -gt 0 ]; then
    echo -e "  ⚠️ ${YELLOW}$NGINX_PROCS Nginx süreci hala çalışıyor${NC}"
    echo -e "     ${YELLOW}🔧 Zorla sonlandırmak için: sudo pkill nginx${NC}"
else
    echo -e "  ✅ ${GREEN}Nginx süreçleri temizlendi${NC}"
fi

echo ""
echo -e "${CYAN}💾 Kaynak Kullanımı:${NC}"

# CPU kullanımı
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
echo -e "  🖥️ CPU Kullanımı: ${GREEN}$CPU_USAGE${NC}"

# RAM kullanımı
RAM_INFO=$(free -h | awk '/^Mem:/ {print $3 "/" $2 " (" int($3/$2 * 100) "%)"}')
echo -e "  🧠 RAM Kullanımı: ${GREEN}$RAM_INFO${NC}"

# Load average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ')
echo -e "  ⚖️ Sistem Yükü: ${GREEN}$LOAD_AVG${NC}"

echo ""
echo -e "${CYAN}📋 Log Bilgileri:${NC}"

# Log dosyası boyutları
ACCESS_LOG_SIZE=$(du -sh /var/log/nginx/access.log 2>/dev/null | cut -f1 || echo "0B")
ERROR_LOG_SIZE=$(du -sh /var/log/nginx/error.log 2>/dev/null | cut -f1 || echo "0B")
APP_LOG_SIZE=$(du -sh /var/log/kodlama-asistani/ 2>/dev/null | cut -f1 || echo "0B")

echo -e "  📊 Nginx access log: ${BLUE}$ACCESS_LOG_SIZE${NC}"
echo -e "  📋 Nginx error log: ${BLUE}$ERROR_LOG_SIZE${NC}"
echo -e "  📝 Uygulama logları: ${BLUE}$APP_LOG_SIZE${NC}"

# Son 5 dakikadaki hata sayısı
RECENT_ERRORS=$(sudo tail -n 1000 /var/log/nginx/error.log 2>/dev/null | grep "$(date -d '5 minutes ago' +'%Y/%m/%d %H:%M')" | wc -l)
if [ "$RECENT_ERRORS" -gt 0 ]; then
    echo -e "  ⚠️ ${YELLOW}Son 5 dakikada $RECENT_ERRORS hata${NC}"
else
    echo -e "  ✅ ${GREEN}Son 5 dakikada hata yok${NC}"
fi

echo ""

# Zorla temizleme seçeneği
if [ "$FLASK_STATUS" = "RUNNING" ] || [ "$NGINX_STATUS" = "RUNNING" ] || [ "$PYTHON_PROCS" -gt 0 ] || [ "$NGINX_PROCS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️ Bazı servisler/süreçler hala çalışıyor${NC}"
    echo ""
    echo -e "${CYAN}🔧 Zorla Temizleme Seçenekleri:${NC}"
    
    read -p "🤔 Tüm süreçleri zorla sonlandırmak istiyor musunuz? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}💥 Zorla temizleme başlatılıyor...${NC}"
        
        # Gunicorn süreçlerini zorla sonlandır
        echo -n "  🐍 Gunicorn süreçleri... "
        if sudo pkill -f "gunicorn.*kodlama-asistani" 2>/dev/null; then
            echo -e "${GREEN}✅ Sonlandırıldı${NC}"
        else
            echo -e "${BLUE}ℹ️ Zaten yok${NC}"
        fi
        
        # Nginx süreçlerini zorla sonlandır
        echo -n "  🌐 Nginx süreçleri... "
        if sudo pkill nginx 2>/dev/null; then
            echo -e "${GREEN}✅ Sonlandırıldı${NC}"
        else
            echo -e "${BLUE}ℹ️ Zaten yok${NC}"
        fi
        
        # Python WebSocket süreçlerini kontrol et
        echo -n "  🔌 Python WebSocket süreçleri... "
        if pkill -f "python.*websocket" 2>/dev/null; then
            echo -e "${GREEN}✅ Sonlandırıldı${NC}"
        else
            echo -e "${BLUE}ℹ️ Zaten yok${NC}"
        fi
        
        # Servis durumlarını zorla sıfırla
        echo -n "  🔄 Servis durumları sıfırlanıyor... "
        sudo systemctl reset-failed kodlama-asistani 2>/dev/null
        sudo systemctl reset-failed nginx 2>/dev/null
        echo -e "${GREEN}✅ Sıfırlandı${NC}"
        
        echo -e "${GREEN}💥 Zorla temizleme tamamlandı!${NC}"
    fi
fi

echo ""

# Genel durum özeti
if [ "$FLASK_STATUS" = "STOPPED" ] && [ "$NGINX_STATUS" = "STOPPED" ]; then
    echo -e "${GREEN}✅ TÜM SERVİSLER BAŞARIYLA DURDURULDU!${NC}"
    
    # Log başarı durumu
    echo "$(date): Sunucu başarıyla durduruldu" >> /var/log/kodlama-asistani/startup.log
    
    echo ""
    echo -e "${CYAN}📋 Sunucu durduruldu. Yeniden başlatmak için:${NC}"
    echo -e "  ${GREEN}./start_server.sh${NC}"
    
elif [ "$FLASK_STOP" = "OK" ] && [ "$NGINX_STOP" = "OK" ]; then
    echo -e "${YELLOW}⚠️ SERVİSLER DURDURULDU (bazı süreçler hala çalışıyor olabilir)${NC}"
    echo ""
    echo -e "${CYAN}📋 Sistem durumunu kontrol etmek için:${NC}"
    echo -e "  ${BLUE}./status.sh${NC}"
    
    # Log kısmi başarı
    echo "$(date): Sunucu kısmen durduruldu" >> /var/log/kodlama-asistani/startup.log
    
else
    echo -e "${RED}❌ BAZI SERVİSLER DURDURULAMADI!${NC}"
    echo ""
    echo -e "${RED}🔧 Manuel müdahale gerekli:${NC}"
    echo -e "  ${YELLOW}sudo systemctl kill kodlama-asistani${NC}"
    echo -e "  ${YELLOW}sudo systemctl kill nginx${NC}"
    echo -e "  ${YELLOW}sudo pkill -f gunicorn${NC}"
    
    # Log hata durumu
    echo "$(date): Sunucu durdurma başarısız" >> /var/log/kodlama-asistani/startup.log
fi

echo ""
echo -e "${CYAN}📋 Diğer Komutlar:${NC}"
echo -e "  ${BLUE}./start_server.sh${NC} - Sunucuyu başlat"
echo -e "  ${BLUE}./restart.sh${NC} - Servisleri yeniden başlat"
echo -e "  ${BLUE}./status.sh${NC} - Sistem durumunu kontrol et"
echo -e "  ${BLUE}./logs.sh${NC} - Sistem loglarını görüntüle"

echo ""
echo -e "${GREEN}🏁 Sunucu durdurma işlemi tamamlandı!${NC}"

# Eğir servisler tam durmazsa exit code 1 döndür
if [ "$FLASK_STATUS" = "RUNNING" ] || [ "$NGINX_STATUS" = "RUNNING" ]; then
    exit 1
fi

exit 0