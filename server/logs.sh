#!/bin/bash
# logs.sh - Kodlama Asistanı Log Görüntüleme Script'i

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Parametreler
LINES=${1:-20}  # Varsayılan olarak son 20 satır
MODE=${2:-all}   # all, flask, nginx, errors, live

show_help() {
    echo -e "${CYAN}📋 Kodlama Asistanı Log Görüntüleme${NC}"
    echo -e "${CYAN}===================================${NC}"
    echo ""
    echo "Kullanım: ./logs.sh [satır_sayısı] [mod]"
    echo ""
    echo "Satır sayısı: Gösterilecek log satırı (varsayılan: 20)"
    echo "Mod seçenekleri:"
    echo "  all     - Tüm loglar (varsayılan)"
    echo "  flask   - Sadece Flask/WebSocket logları"
    echo "  nginx   - Sadece Nginx logları"
    echo "  errors  - Sadece hata logları"
    echo "  live    - Canlı log takibi"
    echo ""
    echo "Örnekler:"
    echo "  ./logs.sh 50        # Son 50 satır"
    echo "  ./logs.sh 100 flask # Flask loglarından son 100 satır"
    echo "  ./logs.sh 0 live    # Canlı log takibi"
    echo ""
    exit 0
}

# Yardım parametresi kontrol
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
fi

echo -e "${CYAN}📋 Kodlama Asistanı Logları${NC}"
echo -e "${CYAN}==========================${NC}"
echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# Canlı log takibi
if [[ "$MODE" == "live" ]]; then
    echo -e "${GREEN}🔴 Canlı log takibi başlatılıyor...${NC}"
    echo -e "${YELLOW}Çıkmak için Ctrl+C basın${NC}"
    echo ""
    
    # Birden fazla log dosyasını takip et
    tail -f \
        /var/log/kodlama-asistani/error.log \
        /var/log/kodlama-asistani/access.log \
        /var/log/nginx/error.log \
        /var/log/nginx/access.log \
        2>/dev/null &
    
    # systemd journal'ı da takip et
    sudo journalctl -u kodlama-asistani -f --no-pager &
    
    # Kullanıcı Ctrl+C basana kadar bekle
    trap 'echo -e "\n${GREEN}Log takibi durduruldu${NC}"; pkill -P $$; exit 0' INT
    wait
    exit 0
fi

# Log dosyası kontrolü fonksiyonu
check_log_file() {
    local file=$1
    local name=$2
    
    if [ -f "$file" ] && [ -r "$file" ]; then
        local size=$(du -sh "$file" 2>/dev/null | cut -f1)
        local lines=$(wc -l < "$file" 2>/dev/null)
        echo -e "  ✅ ${GREEN}$name: $size ($lines satır)${NC}"
        return 0
    else
        echo -e "  ❌ ${RED}$name: Bulunamadı veya okunamıyor${NC}"
        return 1
    fi
}

# Log dosyalarının durumunu kontrol et
echo -e "${PURPLE}📁 LOG DOSYALARI${NC}"
echo -e "${CYAN}───────────────${NC}"

check_log_file "/var/log/kodlama-asistani/error.log" "Flask Error Log"
check_log_file "/var/log/kodlama-asistani/access.log" "Flask Access Log"
check_log_file "/var/log/nginx/error.log" "Nginx Error Log"
check_log_file "/var/log/nginx/access.log" "Nginx Access Log"

# systemd journal kontrolü
echo -n "  📋 Systemd Journal: "
if sudo journalctl -u kodlama-asistani --lines=1 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Erişilebilir${NC}"
else
    echo -e "${RED}❌ Erişim sorunu${NC}"
fi

echo ""

# Flask/WebSocket logları
if [[ "$MODE" == "all" ]] || [[ "$MODE" == "flask" ]]; then
    echo -e "${PURPLE}🌐 FLASK/WEBSOCKET SERVER LOGLARI (Son $LINES)${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..50})${NC}"
    
    if sudo journalctl -u kodlama-asistani --lines="$LINES" --no-pager >/dev/null 2>&1; then
        sudo journalctl -u kodlama-asistani --lines="$LINES" --no-pager | while IFS= read -r line; do
            # Renklendirme
            if echo "$line" | grep -qi "error\|failed\|exception"; then
                echo -e "${RED}$line${NC}"
            elif echo "$line" | grep -qi "warning\|warn"; then
                echo -e "${YELLOW}$line${NC}"
            elif echo "$line" | grep -qi "info\|started\|success"; then
                echo -e "${GREEN}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo -e "${RED}❌ Flask servis logları okunamıyor${NC}"
    fi
    
    echo ""
    
    # Uygulama error log (eğer varsa)
    if [ -f "/var/log/kodlama-asistani/error.log" ]; then
        echo -e "${PURPLE}🔴 UYGULAMA HATA LOGLARI (Son $LINES)${NC}"
        echo -e "${CYAN}$(printf '─%.0s' {1..40})${NC}"
        sudo tail -n "$LINES" /var/log/kodlama-asistani/error.log | while IFS= read -r line; do
            echo -e "${RED}$line${NC}"
        done
        echo ""
    fi
fi

# Nginx logları
if [[ "$MODE" == "all" ]] || [[ "$MODE" == "nginx" ]]; then
    echo -e "${PURPLE}🌐 NGINX ERROR LOGLARI (Son $LINES)${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..35})${NC}"
    
    if [ -f "/var/log/nginx/error.log" ]; then
        sudo tail -n "$LINES" /var/log/nginx/error.log | while IFS= read -r line; do
            if echo "$line" | grep -qi "error"; then
                echo -e "${RED}$line${NC}"
            elif echo "$line" | grep -qi "warn"; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo -e "${RED}❌ Nginx error log bulunamadı${NC}"
    fi
    
    echo ""
    
    echo -e "${PURPLE}🔍 NGINX ACCESS LOGLARI (Son $LINES)${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..35})${NC}"
    
    if [ -f "/var/log/nginx/access.log" ]; then
        sudo tail -n "$LINES" /var/log/nginx/access.log | while IFS= read -r line; do
            # HTTP status koduna göre renklendirme
            if echo "$line" | grep -q '" 2[0-9][0-9] '; then
                echo -e "${GREEN}$line${NC}"
            elif echo "$line" | grep -q '" 3[0-9][0-9] '; then
                echo -e "${BLUE}$line${NC}"
            elif echo "$line" | grep -q '" 4[0-9][0-9] '; then
                echo -e "${YELLOW}$line${NC}"
            elif echo "$line" | grep -q '" 5[0-9][0-9] '; then
                echo -e "${RED}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo -e "${RED}❌ Nginx access log bulunamadı${NC}"
    fi
    
    echo ""
fi

# Sadece hata logları
if [[ "$MODE" == "errors" ]]; then
    echo -e "${PURPLE}🔴 TÜM HATA LOGLARI (Son $LINES)${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..30})${NC}"
    
    # Flask hatalarını topla
    echo -e "${BLUE}📱 Flask Hataları:${NC}"
    sudo journalctl -u kodlama-asistani --lines="$LINES" --no-pager | grep -i "error\|exception\|failed" | tail -n 10 | while IFS= read -r line; do
        echo -e "${RED}  $line${NC}"
    done
    
    echo ""
    
    # Nginx hatalarını topla
    echo -e "${BLUE}🌐 Nginx Hataları:${NC}"
    if [ -f "/var/log/nginx/error.log" ]; then
        sudo tail -n "$LINES" /var/log/nginx/error.log | grep -i "error" | tail -n 10 | while IFS= read -r line; do
            echo -e "${RED}  $line${NC}"
        done
    fi
    
    echo ""
    
    # 4xx ve 5xx HTTP hatalarını topla
    echo -e "${BLUE}🔍 HTTP Hataları:${NC}"
    if [ -f "/var/log/nginx/access.log" ]; then
        sudo tail -n "$LINES" /var/log/nginx/access.log | grep -E '" [45][0-9][0-9] ' | tail -n 10 | while IFS= read -r line; do
            echo -e "${YELLOW}  $line${NC}"
        done
    fi
    
    echo ""
fi

# Log istatistikleri
if [[ "$MODE" == "all" ]]; then
    echo -e "${PURPLE}📊 LOG İSTATİSTİKLERİ${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..25})${NC}"
    
    # Bugünkü aktiviteler
    TODAY=$(date +'%Y-%m-%d')
    echo -e "  📅 Bugün ($TODAY):"
    
    # HTTP istekleri
    if [ -f "/var/log/nginx/access.log" ]; then
        TODAY_REQUESTS=$(sudo grep "$(date +'%d/%b/%Y')" /var/log/nginx/access.log | wc -l)
        echo -e "    📊 HTTP İstekleri: ${BLUE}$TODAY_REQUESTS${NC}"
        
        # HTTP status kodu dağılımı
        if [ "$TODAY_REQUESTS" -gt 0 ]; then
            HTTP_200=$(sudo grep "$(date +'%d/%b/%Y')" /var/log/nginx/access.log | grep '" 200 ' | wc -l)
            HTTP_404=$(sudo grep "$(date +'%d/%b/%Y')" /var/log/nginx/access.log | grep '" 404 ' | wc -l)
            HTTP_500=$(sudo grep "$(date +'%d/%b/%Y')" /var/log/nginx/access.log | grep '" 500 ' | wc -l)
            
            echo -e "      ${GREEN}200 OK: $HTTP_200${NC}"
            if [ "$HTTP_404" -gt 0 ]; then
                echo -e "      ${YELLOW}404 Not Found: $HTTP_404${NC}"
            fi
            if [ "$HTTP_500" -gt 0 ]; then
                echo -e "      ${RED}500 Server Error: $HTTP_500${NC}"
            fi
        fi
    fi
    
    # Hata sayıları
    if [ -f "/var/log/nginx/error.log" ]; then
        TODAY_ERRORS=$(sudo grep "$(date +'%Y/%m/%d')" /var/log/nginx/error.log | wc -l)
        echo -e "    🔴 Nginx Hataları: ${RED}$TODAY_ERRORS${NC}"
    fi
    
    # Flask hataları
    TODAY_FLASK_ERRORS=$(sudo journalctl -u kodlama-asistani --since="today" --no-pager | grep -ci "error\|exception" || echo "0")
    echo -e "    🔴 Flask Hataları: ${RED}$TODAY_FLASK_ERRORS${NC}"
    
    echo ""
    
    # Son 1 saatteki aktivite
    echo -e "  🕐 Son 1 saat:"
    
    if [ -f "/var/log/nginx/access.log" ]; then
        HOUR_REQUESTS=$(sudo tail -n 10000 /var/log/nginx/access.log | grep "$(date -d '1 hour ago' +'%d/%b/%Y:%H')\|$(date +'%d/%b/%Y:%H')" | wc -l)
        echo -e "    📊 HTTP İstekleri: ${BLUE}$HOUR_REQUESTS${NC}"
    fi
    
    # Unique IP adresleri (son 1000 istek)
    if [ -f "/var/log/nginx/access.log" ]; then
        UNIQUE_IPS=$(sudo tail -n 1000 /var/log/nginx/access.log | awk '{print $1}' | sort | uniq | wc -l)
        echo -e "    🌐 Farklı IP: ${BLUE}$UNIQUE_IPS${NC}"
    fi
    
    echo ""
    
    # Top IP adresleri (son 1000 istek)
    echo -e "  🔝 En Aktif IP'ler (Son 1000 istek):"
    if [ -f "/var/log/nginx/access.log" ]; then
        sudo tail -n 1000 /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -5 | while read count ip; do
            echo -e "    ${BLUE}$ip${NC}: $count istek"
        done
    fi
    
    echo ""
    
    # En çok istenen sayfalar
    echo -e "  📄 En Çok İstenen Sayfalar (Son 1000 istek):"
    if [ -f "/var/log/nginx/access.log" ]; then
        sudo tail -n 1000 /var/log/nginx/access.log | awk '{print $7}' | sort | uniq -c | sort -nr | head -5 | while read count path; do
            echo -e "    ${BLUE}$path${NC}: $count istek"
        done
    fi
    
    echo ""
fi

# Log dosyası boyutları ve rotasyon bilgisi
echo -e "${PURPLE}💾 LOG DOSYASI BİLGİLERİ${NC}"
echo -e "${CYAN}$(printf '─%.0s' {1..30})${NC}"

# Dosya boyutları
echo "  📊 Dosya boyutları:"
for log_file in "/var/log/nginx/access.log" "/var/log/nginx/error.log" "/var/log/kodlama-asistani/error.log" "/var/log/kodlama-asistani/access.log"; do
    if [ -f "$log_file" ]; then
        size=$(du -sh "$log_file" 2>/dev/null | cut -f1)
        lines=$(wc -l < "$log_file" 2>/dev/null)
        echo -e "    $(basename "$log_file"): ${YELLOW}$size${NC} ($lines satır)"
    fi
done

# Rotasyon bilgisi
echo ""
echo "  🔄 Log rotasyonu:"
if [ -f "/etc/logrotate.d/kodlama-asistani" ]; then
    echo -e "    ✅ ${GREEN}Otomatik rotasyon aktif${NC}"
else
    echo -e "    ⚠️ ${YELLOW}Otomatik rotasyon ayarlanmamış${NC}"
fi

# Disk kullanımı uyarısı
TOTAL_LOG_SIZE=$(du -sb /var/log/nginx/ /var/log/kodlama-asistani/ 2>/dev/null | awk '{total += $1} END {print total/1024/1024}')
if (( $(echo "$TOTAL_LOG_SIZE > 100" | bc -l) )); then
    echo -e "    ⚠️ ${YELLOW}Toplam log boyutu: ${TOTAL_LOG_SIZE}MB (>100MB)${NC}"
    echo -e "    💡 ${BLUE}Log temizliği önerilir${NC}"
fi

echo ""

# Hızlı komutlar
echo -e "${PURPLE}🎮 HIZLI KOMUTLAR${NC}"
echo -e "${CYAN}$(printf '─%.0s' {1..20})${NC}"
echo -e "  ${BLUE}./logs.sh 50${NC} - Son 50 satır"
echo -e "  ${BLUE}./logs.sh 100 flask${NC} - Flask loglarından 100 satır"
echo -e "  ${BLUE}./logs.sh 0 live${NC} - Canlı log takibi"
echo -e "  ${BLUE}./logs.sh 20 errors${NC} - Sadece hatalar"
echo -e "  ${BLUE}sudo journalctl -u kodlama-asistani -f${NC} - Flask canlı takip"
echo -e "  ${BLUE}sudo tail -f /var/log/nginx/access.log${NC} - Nginx canlı takip"

echo ""

# Log temizleme uyarısı (eğer gerekirse)
if (( $(echo "$TOTAL_LOG_SIZE > 500" | bc -l) )); then
    echo -e "${RED}⚠️ DİKKAT: Log dosyaları çok büyük (${TOTAL_LOG_SIZE}MB)${NC}"
    echo -e "${YELLOW}Log temizliği yapmanız önerilir:${NC}"
    echo -e "  ${BLUE}sudo journalctl --vacuum-time=7d${NC} - 7 günden eski journal'ları sil"
    echo -e "  ${BLUE}sudo logrotate -f /etc/logrotate.d/kodlama-asistani${NC} - Zorla rotasyon"
    echo ""
fi

echo -e "${GREEN}📋 Log görüntüleme tamamlandı!${NC}"

exit 0