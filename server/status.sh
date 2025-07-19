#!/bin/bash
# status.sh - Kodlama Asistanı Sistem Durumu Script'i

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}📊 Kodlama Asistanı Sistem Durumu${NC}"
echo -e "${CYAN}=================================${NC}"
echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# Sistem bilgileri
echo -e "${PURPLE}🖥️ SİSTEM BİLGİLERİ${NC}"
echo -e "${CYAN}─────────────────${NC}"
echo -e "  🏷️ Hostname: ${BLUE}$(hostname)${NC}"
echo -e "  🌐 IP Adresi: ${BLUE}$(hostname -I | awk '{print $1}')${NC}"
echo -e "  💻 OS: ${BLUE}$(lsb_release -d 2>/dev/null | cut -f2 || uname -o)${NC}"
echo -e "  🏗️ Kernel: ${BLUE}$(uname -r)${NC}"
echo -e "  ⏰ Uptime: ${BLUE}$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')${NC}"
echo ""

# Servis durumları
echo -e "${PURPLE}🔧 SERVİS DURUMLARI${NC}"
echo -e "${CYAN}──────────────────${NC}"

# Flask + WebSocket servisi
echo -n "  📱 Flask/WebSocket: "
if systemctl is-active --quiet kodlama-asistani; then
    echo -e "${GREEN}✅ Aktif${NC}"
    FLASK_UPTIME=$(systemctl show kodlama-asistani -p ActiveEnterTimestamp --value | xargs -I {} date -d {} +'%Y-%m-%d %H:%M:%S' 2>/dev/null)
    if [ -n "$FLASK_UPTIME" ]; then
        echo -e "     🕐 Başlatma: ${BLUE}$FLASK_UPTIME${NC}"
    fi
else
    echo -e "${RED}❌ İnaktif${NC}"
    # Son çıkış sebebini göster
    EXIT_CODE=$(systemctl show kodlama-asistani -p ExitCode --value 2>/dev/null)
    if [ -n "$EXIT_CODE" ] && [ "$EXIT_CODE" != "0" ]; then
        echo -e "     ⚠️ Exit Code: ${YELLOW}$EXIT_CODE${NC}"
    fi
fi

# Nginx web server
echo -n "  🌐 Nginx: "
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Aktif${NC}"
    NGINX_UPTIME=$(systemctl show nginx -p ActiveEnterTimestamp --value | xargs -I {} date -d {} +'%Y-%m-%d %H:%M:%S' 2>/dev/null)
    if [ -n "$NGINX_UPTIME" ]; then
        echo -e "     🕐 Başlatma: ${BLUE}$NGINX_UPTIME${NC}"
    fi
else
    echo -e "${RED}❌ İnaktif${NC}"
fi

# Fail2ban (eğer kuruluysa)
if systemctl list-units --full -all | grep -q fail2ban; then
    echo -n "  🛡️ Fail2ban: "
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}✅ Aktif${NC}"
        BANNED_IPS=$(sudo fail2ban-client status 2>/dev/null | grep "Number of banned IP" | awk '{print $NF}' || echo "0")
        echo -e "     🚫 Yasaklı IP: ${YELLOW}$BANNED_IPS${NC}"
    else
        echo -e "${RED}❌ İnaktif${NC}"
    fi
fi

echo ""

# Port durumları
echo -e "${PURPLE}🔌 PORT DURUMLARI${NC}"
echo -e "${CYAN}────────────────${NC}"

check_port() {
    local port=$1
    local service=$2
    local emoji=$3
    
    echo -n "  $emoji Port $port ($service): "
    if netstat -tuln | grep -q ":$port "; then
        echo -e "${GREEN}✅ Açık${NC}"
        # Port üzerindeki bağlantı sayısını göster
        CONNECTIONS=$(netstat -an | grep ":$port" | grep ESTABLISHED | wc -l)
        if [ "$CONNECTIONS" -gt 0 ]; then
            echo -e "     🔗 Aktif bağlantı: ${BLUE}$CONNECTIONS${NC}"
        fi
        return 0
    else
        echo -e "${RED}❌ Kapalı${NC}"
        return 1
    fi
}

check_port "5000" "Flask" "📱"
check_port "8765" "WebSocket" "🔌"
check_port "80" "HTTP" "🌐"
check_port "443" "HTTPS" "🔒"
check_port "22" "SSH" "🔑"

echo ""

# Sistem kaynakları
echo -e "${PURPLE}💾 SİSTEM KAYNAKLARI${NC}"
echo -e "${CYAN}──────────────────${NC}"

# CPU kullanımı
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
CPU_CORES=$(nproc)
echo -e "  🖥️ CPU: ${YELLOW}${CPU_USAGE}%${NC} (${BLUE}${CPU_CORES} core${NC})"

# Load average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ')
echo -e "  ⚖️ Load Average: ${YELLOW}$LOAD_AVG${NC}"

# RAM kullanımı
RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
RAM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')
echo -e "  🧠 RAM: ${YELLOW}${RAM_USED}/${RAM_TOTAL}${NC} (${YELLOW}${RAM_PERCENT}%${NC})"

# Swap kullanımı
SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}')
SWAP_USED=$(free -h | awk '/^Swap:/ {print $3}')
if [ "$SWAP_TOTAL" != "0B" ]; then
    SWAP_PERCENT=$(free | awk '/^Swap:/ {if($2>0) printf "%.1f", $3/$2 * 100; else print "0"}')
    echo -e "  💿 Swap: ${YELLOW}${SWAP_USED}/${SWAP_TOTAL}${NC} (${YELLOW}${SWAP_PERCENT}%${NC})"
fi

# Disk kullanımı
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
DISK_AVAILABLE=$(df -h / | awk 'NR==2 {print $4}')
echo -e "  💽 Disk: ${YELLOW}${DISK_USED}/${DISK_TOTAL}${NC} (${YELLOW}${DISK_PERCENT}${NC}) - ${GREEN}${DISK_AVAILABLE} boş${NC}"

echo ""

# Proje bilgileri
echo -e "${PURPLE}📁 PROJE BİLGİLERİ${NC}"
echo -e "${CYAN}─────────────────${NC}"
PROJECT_DIR="/var/www/kodlama-asistani"
if [ -d "$PROJECT_DIR" ]; then
    PROJECT_SIZE=$(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)
    echo -e "  📂 Proje dizini: ${BLUE}$PROJECT_DIR${NC}"
    echo -e "  📊 Proje boyutu: ${YELLOW}$PROJECT_SIZE${NC}"
    
    # Python sanal ortam kontrolü
    if [ -f "$PROJECT_DIR/venv/bin/activate" ]; then
        echo -e "  🐍 Python venv: ${GREEN}✅ Mevcut${NC}"
        PYTHON_VERSION=$(cd "$PROJECT_DIR" && source venv/bin/activate && python --version 2>/dev/null)
        echo -e "     📝 Versiyon: ${BLUE}$PYTHON_VERSION${NC}"
    else
        echo -e "  🐍 Python venv: ${RED}❌ Bulunamadı${NC}"
    fi
    
    # Konfigürasyon dosyaları
    echo -n "  ⚙️ Konfigürasyon: "
    if [ -f "$PROJECT_DIR/app.py" ] && [ -f "$PROJECT_DIR/gunicorn.conf.py" ]; then
        echo -e "${GREEN}✅ Tamamlandı${NC}"
    else
        echo -e "${RED}❌ Eksik dosyalar${NC}"
    fi
else
    echo -e "  📂 Proje dizini: ${RED}❌ Bulunamadı${NC}"
fi

echo ""

# Log bilgileri
echo -e "${PURPLE}📋 LOG BİLGİLERİ${NC}"
echo -e "${CYAN}─────────────${NC}"

# Uygulama logları
if [ -d "/var/log/kodlama-asistani" ]; then
    APP_LOG_SIZE=$(du -sh /var/log/kodlama-asistani 2>/dev/null | cut -f1)
    echo -e "  📝 Uygulama logları: ${YELLOW}$APP_LOG_SIZE${NC}"
else
    echo -e "  📝 Uygulama logları: ${RED}❌ Bulunamadı${NC}"
fi

# Nginx logları
NGINX_ACCESS_SIZE=$(du -sh /var/log/nginx/access.log 2>/dev/null | cut -f1 || echo "0B")
NGINX_ERROR_SIZE=$(du -sh /var/log/nginx/error.log 2>/dev/null | cut -f1 || echo "0B")
echo -e "  🌐 Nginx access log: ${YELLOW}$NGINX_ACCESS_SIZE${NC}"
echo -e "  🌐 Nginx error log: ${YELLOW}$NGINX_ERROR_SIZE${NC}"

# Son hata kontrolü
RECENT_ERRORS=$(sudo tail -n 100 /var/log/nginx/error.log 2>/dev/null | grep "$(date +'%Y/%m/%d')" | wc -l)
if [ "$RECENT_ERRORS" -gt 0 ]; then
    echo -e "  ⚠️ Bugünkü hatalar: ${YELLOW}$RECENT_ERRORS${NC}"
else
    echo -e "  ✅ Bugün hata yok: ${GREEN}0${NC}"
fi

echo ""

# Ağ bilgileri
echo -e "${PURPLE}🌐 AĞ BİLGİLERİ${NC}"
echo -e "${CYAN}──────────────${NC}"

# İç IP
INTERNAL_IP=$(hostname -I | awk '{print $1}')
echo -e "  🏠 İç IP: ${BLUE}$INTERNAL_IP${NC}"

# Dış IP (eğer ulaşılabilirse)
echo -n "  🌍 Dış IP: "
EXTERNAL_IP=$(timeout 5 curl -s ifconfig.me 2>/dev/null || echo "Tespit edilemedi")
if [ "$EXTERNAL_IP" != "Tespit edilemedi" ]; then
    echo -e "${BLUE}$EXTERNAL_IP${NC}"
else
    echo -e "${YELLOW}Tespit edilemedi${NC}"
fi

echo ""

# Erişim adresleri
echo -e "${PURPLE}🔗 ERİŞİM ADRESLERİ${NC}"
echo -e "${CYAN}─────────────────${NC}"
echo -e "  📱 Web Arayüzü: ${GREEN}http://$INTERNAL_IP${NC}"
echo -e "  📊 API Status: ${BLUE}http://$INTERNAL_IP/api/status${NC}"
echo -e "  🏥 Health Check: ${BLUE}http://$INTERNAL_IP/api/health${NC}"

if [ "$EXTERNAL_IP" != "Tespit edilemedi" ] && [ "$EXTERNAL_IP" != "$INTERNAL_IP" ]; then
    echo -e "  🌐 Dış Erişim: ${CYAN}http://$EXTERNAL_IP${NC}"
fi

echo ""

# API durum testi
echo -e "${PURPLE}🧪 API DURUM TESTLERİ${NC}"
echo -e "${CYAN}───────────────────${NC}"

# Health check
echo -n "  🏥 Health Check: "
if HEALTH_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/health_check.json http://localhost/api/health 2>/dev/null); then
    HTTP_CODE="${HEALTH_RESPONSE: -3}"
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ OK (200)${NC}"
        if [ -f "/tmp/health_check.json" ]; then
            STATUS=$(jq -r '.status // "unknown"' /tmp/health_check.json 2>/dev/null || echo "unknown")
            echo -e "     📊 Status: ${BLUE}$STATUS${NC}"
        fi
    else
        echo -e "${RED}❌ HTTP $HTTP_CODE${NC}"
    fi
else
    echo -e "${RED}❌ Bağlantı hatası${NC}"
fi

# Status API
echo -n "  📊 Status API: "
if STATUS_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/status_check.json http://localhost/api/status 2>/dev/null); then
    HTTP_CODE="${STATUS_RESPONSE: -3}"
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ OK (200)${NC}"
        if [ -f "/tmp/status_check.json" ]; then
            HOME_CLIENTS=$(jq -r '.clients.home_clients // 0' /tmp/status_check.json 2>/dev/null || echo "0")
            WEB_CLIENTS=$(jq -r '.clients.web_clients // 0' /tmp/status_check.json 2>/dev/null || echo "0")
            echo -e "     🏠 Ev client'ları: ${BLUE}$HOME_CLIENTS${NC}"
            echo -e "     🌐 Web client'ları: ${BLUE}$WEB_CLIENTS${NC}"
        fi
    else
        echo -e "${RED}❌ HTTP $HTTP_CODE${NC}"
    fi
else
    echo -e "${RED}❌ Bağlantı hatası${NC}"
fi

# Ana sayfa testi
echo -n "  🌐 Ana Sayfa: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    echo -e "${GREEN}✅ OK (200)${NC}"
else
    echo -e "${RED}❌ Erişim hatası${NC}"
fi

echo ""

# Güvenlik durumu
echo -e "${PURPLE}🔒 GÜVENLİK DURUMU${NC}"
echo -e "${CYAN}─────────────────${NC}"

# UFW durumu
echo -n "  🔥 UFW Firewall: "
UFW_STATUS=$(sudo ufw status | head -n1 | awk '{print $2}')
if [ "$UFW_STATUS" = "active" ]; then
    echo -e "${GREEN}✅ Aktif${NC}"
    UFW_RULES=$(sudo ufw status numbered | grep -c "ALLOW")
    echo -e "     📋 Kurallar: ${BLUE}$UFW_RULES${NC}"
else
    echo -e "${RED}❌ İnaktif${NC}"
fi

# Fail2ban durumu (eğer kuruluysa)
if command -v fail2ban-client &> /dev/null; then
    echo -n "  🛡️ Fail2ban: "
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}✅ Aktif${NC}"
        BANNED_COUNT=$(sudo fail2ban-client status 2>/dev/null | grep "Currently banned" | awk '{print $4}' || echo "0")
        echo -e "     🚫 Yasaklı IP: ${YELLOW}$BANNED_COUNT${NC}"
    else
        echo -e "${RED}❌ İnaktif${NC}"
    fi
fi

# SSH bağlantıları
SSH_CONNECTIONS=$(who | wc -l)
echo -e "  🔑 SSH Bağlantıları: ${BLUE}$SSH_CONNECTIONS${NC}"

echo ""

# Son aktiviteler
echo -e "${PURPLE}📈 SON AKTİVİTELER${NC}"
echo -e "${CYAN}─────────────────${NC}"

# Son 5 dakikadaki HTTP istekleri
RECENT_REQUESTS=$(sudo tail -n 1000 /var/log/nginx/access.log 2>/dev/null | grep "$(date -d '5 minutes ago' +'%d/%b/%Y:%H:%M')" | wc -l)
echo -e "  📊 Son 5dk HTTP isteği: ${BLUE}$RECENT_REQUESTS${NC}"

# Son başlatma zamanı
if [ -f "/var/log/kodlama-asistani/startup.log" ]; then
    LAST_START=$(tail -n5 /var/log/kodlama-asistani/startup.log | grep "başarıyla başlatıldı" | tail -n1 | cut -d: -f1-2)
    if [ -n "$LAST_START" ]; then
        echo -e "  🚀 Son başlatma: ${BLUE}$LAST_START${NC}"
    fi
fi

echo ""

# Öneriler
echo -e "${PURPLE}💡 ÖNERİLER${NC}"
echo -e "${CYAN}──────────${NC}"

RECOMMENDATIONS=()

# CPU yüksekse
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    RECOMMENDATIONS+=("🖥️ CPU kullanımı yüksek (%${CPU_USAGE}) - sistem yükünü kontrol edin")
fi

# RAM yüksekse
if (( $(echo "$RAM_PERCENT > 80" | bc -l) )); then
    RECOMMENDATIONS+=("🧠 RAM kullanımı yüksek (%${RAM_PERCENT}) - bellek optimizasyonu yapın")
fi

# Disk doluysa
DISK_PERCENT_NUM=$(echo "$DISK_PERCENT" | tr -d '%')
if [ "$DISK_PERCENT_NUM" -gt 80 ]; then
    RECOMMENDATIONS+=("💽 Disk kullanımı yüksek ($DISK_PERCENT) - log rotasyonu kontrol edin")
fi

# Son hatalar varsa
if [ "$RECENT_ERRORS" -gt 5 ]; then
    RECOMMENDATIONS+=("⚠️ Çok fazla hata ($RECENT_ERRORS) - logları kontrol edin: ./logs.sh")
fi

# Servis durumu kontrol
if ! systemctl is-active --quiet kodlama-asistani; then
    RECOMMENDATIONS+=("📱 Flask servisi çalışmıyor - başlatın: ./start_server.sh")
fi

if ! systemctl is-active --quiet nginx; then
    RECOMMENDATIONS+=("🌐 Nginx servisi çalışmıyor - başlatın: sudo systemctl start nginx")
fi

# Önerileri yazdır
if [ ${#RECOMMENDATIONS[@]} -eq 0 ]; then
    echo -e "  ✅ ${GREEN}Sistem optimal durumda!${NC}"
else
    for rec in "${RECOMMENDATIONS[@]}"; do
        echo -e "  $rec"
    done
fi

echo ""

# Hızlı komutlar
echo -e "${PURPLE}🎮 HIZLI KOMUTLAR${NC}"
echo -e "${CYAN}─────────────────${NC}"
echo -e "  ${BLUE}./start_server.sh${NC} - Sunucuyu başlat"
echo -e "  ${BLUE}./stop_server.sh${NC} - Sunucuyu durdur"
echo -e "  ${BLUE}./restart.sh${NC} - Servisleri yeniden başlat"
echo -e "  ${BLUE}./logs.sh${NC} - Detaylı logları görüntüle"
echo -e "  ${BLUE}./test.sh${NC} - Kapsamlı sistem testi"

echo ""
echo -e "${GREEN}📊 Sistem durumu raporu tamamlandı!${NC}"

# Temizlik
rm -f /tmp/health_check.json /tmp/status_check.json 2>/dev/null

exit 0