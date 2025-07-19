#!/bin/bash
# test.sh - Kodlama Asistanı Kapsamlı Sistem Test Script'i

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Test sayaçları
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Test kategorileri
CATEGORIES=("Dosya ve Dizin" "Python Ortamı" "Sistem Servisleri" "Ağ ve Portlar" "HTTP/API" "WebSocket" "Güvenlik" "Performans" "Log Sistemi")

echo -e "${WHITE}🧪 KODLAMA ASISTANI - KAPSAMLI SİSTEM TESTİ${NC}"
echo -e "${WHITE}==============================================${NC}"
echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}Test süreci başlatılıyor...${NC}"
echo ""

PROJECT_DIR="/var/www/kodlama-asistani"
SERVER_IP=$(hostname -I | awk '{print $1}')

# Test fonksiyonu
run_test() {
    local category="$1"
    local test_name="$2"
    local test_command="$3"
    local critical="$4"  # true/false - kritik test mi?
    
    ((TOTAL_TESTS++))
    echo -n "🔍 $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ BAŞARILI${NC}"
        ((PASSED_TESTS++))
        return 0
    else
        if [ "$critical" = "true" ]; then
            echo -e "${RED}❌ BAŞARISIZ (KRİTİK)${NC}"
            ((FAILED_TESTS++))
        else
            echo -e "${YELLOW}⚠️ BAŞARISIZ${NC}"
            ((WARNING_TESTS++))
        fi
        return 1
    fi
}

# Detaylı test fonksiyonu
run_detailed_test() {
    local category="$1"
    local test_name="$2"
    local test_command="$3"
    local critical="$4"
    local success_msg="$5"
    local failure_msg="$6"
    
    ((TOTAL_TESTS++))
    echo -n "🔍 $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ BAŞARILI${NC}"
        if [ -n "$success_msg" ]; then
            echo -e "   ${BLUE}$success_msg${NC}"
        fi
        ((PASSED_TESTS++))
        return 0
    else
        if [ "$critical" = "true" ]; then
            echo -e "${RED}❌ BAŞARISIZ (KRİTİK)${NC}"
            ((FAILED_TESTS++))
        else
            echo -e "${YELLOW}⚠️ BAŞARISIZ${NC}"
            ((WARNING_TESTS++))
        fi
        if [ -n "$failure_msg" ]; then
            echo -e "   ${YELLOW}$failure_msg${NC}"
        fi
        return 1
    fi
}

# Test kategorisi başlığı
print_category() {
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}📋 $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════${NC}"
}

# 1. DOSYA VE DİZİN TESTLERİ
print_category "DOSYA VE DİZİN TESTLERİ"

run_test "Dosya" "Proje dizini varlığı" "[ -d '$PROJECT_DIR' ]" "true"
run_test "Dosya" "Flask app.py dosyası" "[ -f '$PROJECT_DIR/app.py' ]" "true"
run_test "Dosya" "Gunicorn konfigürasyonu" "[ -f '$PROJECT_DIR/gunicorn.conf.py' ]" "true"
run_test "Dosya" "Requirements dosyası" "[ -f '$PROJECT_DIR/requirements.txt' ]" "true"
run_test "Dosya" "Log dizini" "[ -d '/var/log/kodlama-asistani' ]" "false"
run_test "Dosya" "Log dizini yazma izni" "[ -w '/var/log/kodlama-asistani' ]" "false"

# 2. PYTHON ORTAMI TESTLERİ
print_category "PYTHON ORTAMI TESTLERİ"

run_test "Python" "Python sanal ortam" "[ -f '$PROJECT_DIR/venv/bin/activate' ]" "true"
run_detailed_test "Python" "Python sürümü" "cd '$PROJECT_DIR' && source venv/bin/activate && python --version | grep -q 'Python 3'" "true" "$(cd "$PROJECT_DIR" && source venv/bin/activate && python --version 2>/dev/null)"
run_test "Python" "Flask paketi" "cd '$PROJECT_DIR' && source venv/bin/activate && python -c 'import flask'" "true"
run_test "Python" "WebSockets paketi" "cd '$PROJECT_DIR' && source venv/bin/activate && python -c 'import websockets'" "true"
run_test "Python" "Requests paketi" "cd '$PROJECT_DIR' && source venv/bin/activate && python -c 'import requests'" "true"
run_test "Python" "Gunicorn paketi" "cd '$PROJECT_DIR' && source venv/bin/activate && python -c 'import gunicorn'" "true"

# 3. SİSTEM SERVİSLERİ TESTLERİ
print_category "SİSTEM SERVİSLERİ TESTLERİ"

run_test "Servis" "Systemd servis dosyası" "[ -f '/etc/systemd/system/kodlama-asistani.service' ]" "true"
run_detailed_test "Servis" "Flask servis durumu" "systemctl is-active --quiet kodlama-asistani" "true" "Servis aktif ve çalışıyor" "Servis çalışmıyor - başlatın: sudo systemctl start kodlama-asistani"
run_detailed_test "Servis" "Nginx servis durumu" "systemctl is-active --quiet nginx" "true" "Nginx aktif ve çalışıyor" "Nginx çalışmıyor - başlatın: sudo systemctl start nginx"
run_test "Servis" "Flask servis aktif edilmiş mi" "systemctl is-enabled --quiet kodlama-asistani" "false"
run_test "Servis" "Nginx servis aktif edilmiş mi" "systemctl is-enabled --quiet nginx" "false"

# Servis detayları
if systemctl is-active --quiet kodlama-asistani; then
    FLASK_UPTIME=$(systemctl show kodlama-asistani -p ActiveEnterTimestamp --value 2>/dev/null)
    if [ -n "$FLASK_UPTIME" ]; then
        echo -e "   ${BLUE}Flask başlatma zamanı: $FLASK_UPTIME${NC}"
    fi
fi

if systemctl is-active --quiet nginx; then
    NGINX_UPTIME=$(systemctl show nginx -p ActiveEnterTimestamp --value 2>/dev/null)
    if [ -n "$NGINX_UPTIME" ]; then
        echo -e "   ${BLUE}Nginx başlatma zamanı: $NGINX_UPTIME${NC}"
    fi
fi

# 4. AĞ VE PORT TESTLERİ
print_category "AĞ VE PORT TESTLERİ"

run_detailed_test "Ağ" "Port 5000 (Flask)" "netstat -tuln | grep -q ':5000'" "true" "Flask HTTP portu açık" "Flask portu kapalı - servis çalışmıyor olabilir"
run_detailed_test "Ağ" "Port 8765 (WebSocket)" "netstat -tuln | grep -q ':8765'" "true" "WebSocket portu açık" "WebSocket portu kapalı - app.py'de sorun olabilir"
run_detailed_test "Ağ" "Port 80 (HTTP)" "netstat -tuln | grep -q ':80'" "true" "HTTP portu açık" "HTTP portu kapalı - nginx çalışmıyor olabilir"
run_test "Ağ" "Port 443 (HTTPS)" "netstat -tuln | grep -q ':443'" "false"
run_test "Ağ" "Port 22 (SSH)" "netstat -tuln | grep -q ':22'" "false"

# Bağlantı sayıları
HTTP_CONNECTIONS=$(netstat -an | grep ":80" | grep ESTABLISHED | wc -l)
WS_CONNECTIONS=$(netstat -an | grep ":8765" | grep ESTABLISHED | wc -l)
echo -e "   ${BLUE}HTTP bağlantıları: $HTTP_CONNECTIONS aktif${NC}"
echo -e "   ${BLUE}WebSocket bağlantıları: $WS_CONNECTIONS aktif${NC}"

# 5. HTTP/API TESTLERİ
print_category "HTTP/API TESTLERİ"

if command -v curl &> /dev/null; then
    run_detailed_test "HTTP" "Ana sayfa erişimi" "curl -f -s --max-time 10 http://localhost/ >/dev/null" "true" "Ana sayfa yanıt veriyor" "Ana sayfa erişilemiyor - nginx veya flask sorunu"
    run_detailed_test "API" "Health endpoint" "curl -f -s --max-time 10 http://localhost/api/health >/dev/null" "true" "Health API çalışıyor" "Health API yanıt vermiyor"
    run_detailed_test "API" "Status endpoint" "curl -f -s --max-time 10 http://localhost/api/status >/dev/null" "true" "Status API çalışıyor" "Status API yanıt vermiyor"
    
    # API yanıt zamanı testi
    echo -n "🔍 API yanıt zamanı testi... "
    RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" --max-time 5 http://localhost/api/health 2>/dev/null || echo "timeout")
    if [ "$RESPONSE_TIME" != "timeout" ]; then
        echo -e "${GREEN}✅ BAŞARILI${NC}"
        echo -e "   ${BLUE}Yanıt zamanı: ${RESPONSE_TIME}s${NC}"
        ((TOTAL_TESTS++))
        ((PASSED_TESTS++))
    else
        echo -e "${YELLOW}⚠️ ZAMAN AŞIMI${NC}"
        ((TOTAL_TESTS++))
        ((WARNING_TESTS++))
    fi
    
    # HTTP status kodları testi
    echo -n "🔍 HTTP status kodları... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost/ 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ BAŞARILI (200 OK)${NC}"
        ((TOTAL_TESTS++))
        ((PASSED_TESTS++))
    else
        echo -e "${RED}❌ BAŞARISIZ (HTTP $HTTP_CODE)${NC}"
        ((TOTAL_TESTS++))
        ((FAILED_TESTS++))
    fi
    
else
    echo -e "${YELLOW}⚠️ curl komutu bulunamadı, HTTP testleri atlanıyor${NC}"
fi

# 6. WEBSOCKET TESTLERİ
print_category "WEBSOCKET TESTLERİ"

run_detailed_test "WebSocket" "WebSocket port bağlantısı" "timeout 5 bash -c 'echo > /dev/tcp/localhost/8765'" "true" "WebSocket portu erişilebilir" "WebSocket portu erişilemiyor"

# WebSocket protokol testi (eğer websocat kuruluysa)
if command -v websocat &> /dev/null; then
    echo -n "🔍 WebSocket protokol testi... "
    if timeout 5 websocat ws://localhost:8765 <<<'{"type":"ping"}' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ BAŞARILI${NC}"
        ((TOTAL_TESTS++))
        ((PASSED_TESTS++))
    else
        echo -e "${YELLOW}⚠️ PROTOKOL HATASI${NC}"
        ((TOTAL_TESTS++))
        ((WARNING_TESTS++))
    fi
else
    echo -e "   ${BLUE}websocat bulunamadı, protokol testi atlanıyor${NC}"
fi

# 7. GÜVENLİK TESTLERİ
print_category "GÜVENLİK TESTLERİ"

run_detailed_test "Güvenlik" "UFW Firewall durumu" "sudo ufw status | grep -q 'Status: active'" "false" "UFW aktif ve çalışıyor" "UFW aktif değil - güvenlik riski"
run_test "Güvenlik" "Nginx konfigürasyon geçerliliği" "sudo nginx -t" "true"

# Fail2ban kontrolü
if command -v fail2ban-client &> /dev/null; then
    run_test "Güvenlik" "Fail2ban servis durumu" "systemctl is-active --quiet fail2ban" "false"
    if systemctl is-active --quiet fail2ban; then
        BANNED_IPS=$(sudo fail2ban-client status 2>/dev/null | grep -o "Currently banned:.*" | awk '{print $3}' || echo "0")
        echo -e "   ${BLUE}Yasaklı IP sayısı: $BANNED_IPS${NC}"
    fi
else
    echo -e "   ${YELLOW}Fail2ban kurulu değil${NC}"
fi

# Dosya izinleri kontrolü
run_test "Güvenlik" "App.py dosya izinleri" "[ $(stat -c '%a' '$PROJECT_DIR/app.py' 2>/dev/null) -le 755 ]" "false"
run_test "Güvenlik" "Log dizini izinleri" "[ $(stat -c '%a' '/var/log/kodlama-asistani' 2>/dev/null) -le 755 ]" "false"

# 8. PERFORMANS TESTLERİ
print_category "PERFORMANS TESTLERİ"

# CPU kullanımı
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
echo -n "🔍 CPU kullanımı kontrolü... "
if (( $(echo "$CPU_USAGE < 80" | bc -l) )); then
    echo -e "${GREEN}✅ NORMAL (${CPU_USAGE}%)${NC}"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
else
    echo -e "${YELLOW}⚠️ YÜKSEK (${CPU_USAGE}%)${NC}"
    ((TOTAL_TESTS++))
    ((WARNING_TESTS++))
fi

# RAM kullanımı
RAM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')
echo -n "🔍 RAM kullanımı kontrolü... "
if (( $(echo "$RAM_PERCENT < 80" | bc -l) )); then
    echo -e "${GREEN}✅ NORMAL (${RAM_PERCENT}%)${NC}"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
else
    echo -e "${YELLOW}⚠️ YÜKSEK (${RAM_PERCENT}%)${NC}"
    ((TOTAL_TESTS++))
    ((WARNING_TESTS++))
fi

# Disk kullanımı
DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
echo -n "🔍 Disk kullanımı kontrolü... "
if [ "$DISK_PERCENT" -lt 80 ]; then
    echo -e "${GREEN}✅ NORMAL (${DISK_PERCENT}%)${NC}"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
else
    echo -e "${YELLOW}⚠️ YÜKSEK (${DISK_PERCENT}%)${NC}"
    ((TOTAL_TESTS++))
    ((WARNING_TESTS++))
fi

# Load average
LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
CORES=$(nproc)
echo -e "   ${BLUE}Load average (1dk): $LOAD_1MIN (${CORES} core)${NC}"

# 9. LOG SİSTEMİ TESTLERİ
print_category "LOG SİSTEMİ TESTLERİ"

run_test "Log" "Systemd journal erişimi" "sudo journalctl -u kodlama-asistani --lines=1 >/dev/null" "false"
run_test "Log" "Nginx access log" "[ -f '/var/log/nginx/access.log' ]" "false"
run_test "Log" "Nginx error log" "[ -f '/var/log/nginx/error.log' ]" "false"
run_test "Log" "Uygulama log dizini" "[ -d '/var/log/kodlama-asistani' ]" "false"

# Log boyutları
if [ -f "/var/log/nginx/access.log" ]; then
    ACCESS_LOG_SIZE=$(du -sh /var/log/nginx/access.log | cut -f1)
    echo -e "   ${BLUE}Nginx access log: $ACCESS_LOG_SIZE${NC}"
fi

if [ -f "/var/log/nginx/error.log" ]; then
    ERROR_LOG_SIZE=$(du -sh /var/log/nginx/error.log | cut -f1)
    echo -e "   ${BLUE}Nginx error log: $ERROR_LOG_SIZE${NC}"
fi

# Son hataları kontrol et
RECENT_ERRORS=$(sudo tail -n 100 /var/log/nginx/error.log 2>/dev/null | grep "$(date +'%Y/%m/%d')" | wc -l)
echo -n "🔍 Bugünkü hata sayısı... "
if [ "$RECENT_ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✅ HİÇ HATA YOK${NC}"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
elif [ "$RECENT_ERRORS" -lt 10 ]; then
    echo -e "${YELLOW}⚠️ AZ HATA ($RECENT_ERRORS)${NC}"
    ((TOTAL_TESTS++))
    ((WARNING_TESTS++))
else
    echo -e "${RED}❌ ÇOK HATA ($RECENT_ERRORS)${NC}"
    ((TOTAL_TESTS++))
    ((FAILED_TESTS++))
fi

# 10. İNTEGRASYON TESTLERİ
print_category "İNTEGRASYON TESTLERİ"

# API JSON response testi
if command -v curl &> /dev/null && command -v jq &> /dev/null; then
    echo -n "🔍 API JSON formatı... "
    if curl -s http://localhost/api/health | jq empty >/dev/null 2>&1; then
        echo -e "${GREEN}✅ GEÇERLİ JSON${NC}"
        ((TOTAL_TESTS++))
        ((PASSED_TESTS++))
    else
        echo -e "${RED}❌ GEÇERSİZ JSON${NC}"
        ((TOTAL_TESTS++))
        ((FAILED_TESTS++))
    fi
elif ! command -v jq &> /dev/null; then
    echo -e "   ${YELLOW}jq komutu bulunamadı, JSON testi atlanıyor${NC}"
fi

# Nginx proxy testi
echo -n "🔍 Nginx proxy yönlendirmesi... "
if curl -s -H "Host: localhost" http://localhost/ | grep -q "Kodlama Asistanı" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PROXY ÇALIŞIYOR${NC}"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
else
    echo -e "${RED}❌ PROXY SORUNU${NC}"
    ((TOTAL_TESTS++))
    ((FAILED_TESTS++))
fi

# ============================================================================
# TEST SONUÇLARI
# ============================================================================

echo ""
echo -e "${WHITE}📊 TEST SONUÇLARI${NC}"
echo -e "${WHITE}═══════════════════════════════════════════════${NC}"

# Genel istatistikler
echo -e "${BLUE}📋 Genel İstatistikler:${NC}"
echo -e "  • Toplam Test: ${WHITE}$TOTAL_TESTS${NC}"
echo -e "  • Başarılı: ${GREEN}$PASSED_TESTS${NC}"
echo -e "  • Başarısız: ${RED}$FAILED_TESTS${NC}"
echo -e "  • Uyarı: ${YELLOW}$WARNING_TESTS${NC}"

# Başarı yüzdesi
if [ "$TOTAL_TESTS" -gt 0 ]; then
    SUCCESS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    echo -e "  • Başarı Oranı: ${WHITE}%$SUCCESS_RATE${NC}"
fi

echo ""

# Sistem durumu özeti
echo -e "${BLUE}🖥️ Sistem Durumu:${NC}"
echo -e "  • Sunucu IP: ${CYAN}$SERVER_IP${NC}"
echo -e "  • Test Zamanı: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "  • Uptime: ${CYAN}$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')${NC}"

echo ""

# Erişim bilgileri
echo -e "${BLUE}🌍 Erişim Adresleri:${NC}"
echo -e "  • Web Arayüzü: ${GREEN}http://$SERVER_IP${NC}"
echo -e "  • API Status: ${BLUE}http://$SERVER_IP/api/status${NC}"
echo -e "  • Health Check: ${BLUE}http://$SERVER_IP/api/health${NC}"

echo ""

# Genel durum değerlendirmesi
if [ "$FAILED_TESTS" -eq 0 ] && [ "$WARNING_TESTS" -lt 3 ]; then
    echo -e "${GREEN}🎉 SİSTEM MÜKEMMEL DURUMDA!${NC}"
    echo -e "${GREEN}✅ Tüm kritik testler başarılı${NC}"
    echo -e "${GREEN}🚀 Sistem production'a hazır${NC}"
    OVERALL_STATUS="EXCELLENT"
    
elif [ "$FAILED_TESTS" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ SİSTEM İYİ DURUMDA${NC}"
    echo -e "${YELLOW}✅ Kritik testler başarılı, ufak iyileştirmeler yapılabilir${NC}"
    OVERALL_STATUS="GOOD"
    
elif [ "$FAILED_TESTS" -lt 3 ]; then
    echo -e "${YELLOW}🔧 SİSTEMDE UFAK SORUNLAR VAR${NC}"
    echo -e "${YELLOW}⚠️ Bazı kritik olmayan testler başarısız${NC}"
    OVERALL_STATUS="NEEDS_ATTENTION"
    
else
    echo -e "${RED}❌ SİSTEMDE CİDDİ SORUNLAR VAR!${NC}"
    echo -e "${RED}🔧 Kritik sorunlar giderilmeli${NC}"
    OVERALL_STATUS="CRITICAL"
fi

echo ""

# Öneriler
if [ "$FAILED_TESTS" -gt 0 ] || [ "$WARNING_TESTS" -gt 5 ]; then
    echo -e "${PURPLE}💡 ÖNERİLER:${NC}"
    
    if [ "$FAILED_TESTS" -gt 0 ]; then
        echo -e "  🔴 Kritik sorunlar için:"
        echo -e "    • ${BLUE}./logs.sh errors${NC} - Hata loglarını inceleyin"
        echo -e "    • ${BLUE}./restart.sh${NC} - Servisleri yeniden başlatın"
        echo -e "    • ${BLUE}sudo systemctl status kodlama-asistani${NC} - Servis durumunu kontrol edin"
    fi
    
    if [ "$WARNING_TESTS" -gt 3 ]; then
        echo -e "  🟡 İyileştirmeler için:"
        echo -e "    • ${BLUE}./status.sh${NC} - Detaylı sistem durumunu kontrol edin"
        echo -e "    • Log rotasyonu ayarlayın"
        echo -e "    • Sistem kaynaklarını optimize edin"
    fi
    
    echo ""
fi

# Hızlı komutlar
echo -e "${PURPLE}🎮 HIZLI KOMUTLAR:${NC}"
echo -e "  • ${BLUE}./status.sh${NC} - Detaylı sistem durumu"
echo -e "  • ${BLUE}./logs.sh${NC} - Sistem logları"
echo -e "  • ${BLUE}./restart.sh${NC} - Servisleri yeniden başlat"
echo -e "  • ${BLUE}./start_server.sh${NC} - Sunucuyu başlat"
echo -e "  • ${BLUE}./stop_server.sh${NC} - Sunucuyu durdur"

echo ""

# Test raporu dosyası oluştur
TEST_REPORT="/var/log/kodlama-asistani/test_report_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "Kodlama Asistanı Test Raporu"
    echo "============================"
    echo "Test Zamanı: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Sunucu IP: $SERVER_IP"
    echo ""
    echo "Test Sonuçları:"
    echo "  Toplam: $TOTAL_TESTS"
    echo "  Başarılı: $PASSED_TESTS"
    echo "  Başarısız: $FAILED_TESTS"
    echo "  Uyarı: $WARNING_TESTS"
    echo "  Başarı Oranı: %$SUCCESS_RATE"
    echo ""
    echo "Genel Durum: $OVERALL_STATUS"
    echo ""
    echo "Sistem Kaynakları:"
    echo "  CPU: ${CPU_USAGE}%"
    echo "  RAM: ${RAM_PERCENT}%"
    echo "  Disk: ${DISK_PERCENT}%"
    echo "  Load: $LOAD_1MIN"
} > "$TEST_REPORT" 2>/dev/null

if [ -f "$TEST_REPORT" ]; then
    echo -e "${BLUE}📄 Test raporu kaydedildi: $TEST_REPORT${NC}"
fi

echo ""
echo -e "${GREEN}🧪 Kapsamlı sistem testi tamamlandı!${NC}"

# Exit code
if [ "$FAILED_TESTS" -gt 0 ]; then
    exit 1
elif [ "$WARNING_TESTS" -gt 5 ]; then
    exit 2
else
    exit 0
fi