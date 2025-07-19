#!/bin/bash
# ==========================================
# monitor.sh - Sistem İzleme Script'i  
# ==========================================

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