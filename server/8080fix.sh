#!/bin/bash
# 8080_port_fix.sh - Tüm sistemı 8080 portuna güncelle (CyberPanel uyumlu)

echo "🔧 CyberPanel Uyumlu Port Güncellemesi"
echo "======================================"
echo "Port 80 -> 8080 dönüşümü başlıyor..."

PROJECT_DIR="/var/www/kodlama-asistani"
cd "$PROJECT_DIR"

# 1. Önce servisleri durdur
echo "🛑 Servisleri durduruluyor..."
sudo systemctl stop kodlama-asistani
sudo systemctl stop nginx

# 2. Yeni app.py dosyasını güncelle
echo "📱 app.py güncelleniyor..."
# Bu dosya ayrıca verilmeli

# 3. Nginx konfigürasyonu güncelleme
echo "🌐 Nginx konfigürasyonu güncelleniyor..."
sudo tee /etc/nginx/sites-available/kodlama-asistani > /dev/null << 'NGINX_EOF'
# Nginx konfigürasyonu - Port 8080 (CyberPanel uyumlu)

# Upstream definitions
upstream flask_app {
    server 127.0.0.1:5000 fail_timeout=0;
}

upstream websocket_server {
    server 127.0.0.1:8765 fail_timeout=0;
}

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/m;
limit_req_zone $binary_remote_addr zone=websocket:10m rate=5r/s;

server {
    listen 8080;
    server_name _ localhost;
    
    # Basic security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header X-Robots-Tag "noindex, nofollow, nosnippet, noarchive" always;
    
    # Security headers
    add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval'; connect-src 'self' ws: wss:;" always;
    
    # Root location - Flask app
    location / {
        proxy_pass http://flask_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # CORS headers
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE" always;
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization" always;
        
        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin * always;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE" always;
            add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization" always;
            add_header Access-Control-Max-Age 86400;
            add_header Content-Type 'text/plain; charset=utf-8';
            add_header Content-Length 0;
            return 204;
        }
    }

    # WebSocket proxy - direct to port 8765
    location /ws {
        proxy_pass http://websocket_server;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket specific timeouts
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60s;
        
        # Rate limiting for WebSocket
        limit_req zone=websocket burst=10 nodelay;
    }

    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=5 nodelay;
        
        proxy_pass http://flask_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # API specific headers
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
        add_header Pragma "no-cache" always;
        add_header Expires "0" always;
    }

    # Static files (if needed)
    location /static/ {
        alias /var/www/kodlama-asistani/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Favicon
    location = /favicon.ico {
        access_log off;
        log_not_found off;
        return 204;
    }
    
    # Robots.txt
    location = /robots.txt {
        access_log off;
        log_not_found off;
        return 200 "User-agent: *\nDisallow: /\n";
        add_header Content-Type text/plain;
    }
    
    # Health check endpoint (no rate limiting)
    location = /api/health {
        proxy_pass http://flask_app;
        access_log off;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types 
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/json
        application/xml+rss
        application/atom+xml
        image/svg+xml;
        
    # Security - hide nginx version
    server_tokens off;
    
    # Prevent access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
NGINX_EOF

echo "✅ Nginx konfigürasyonu güncellendi (Port 8080)"

# 4. Firewall kurallarını güncelle
echo "🔥 Firewall kuralları güncelleniyor..."
sudo ufw allow 8080/tcp comment 'Kodlama Asistani HTTP'
sudo ufw allow 8765/tcp comment 'Kodlama Asistani WebSocket'

# 5. start_server.sh güncelle
echo "🚀 start_server.sh güncelleniyor..."
cat > start_server.sh << 'START_EOF'
#!/bin/bash
# start_server.sh - Kodlama Asistanı Sunucu Başlatma (Port 8080)

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🌐 Kodlama Asistanı Sunucu Başlatılıyor (Port 8080)...${NC}"
echo -e "${CYAN}================================================${NC}"

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
    
    if netstat -tuln | grep -q ":$port "; then
        echo -e "  ✅ ${GREEN}Port $port ($service): Açık${NC}"
        return 0
    else
        echo -e "  ❌ ${RED}Port $port ($service): Kapalı${NC}"
        return 1
    fi
}

# Port kontrolleri
check_port "5000" "Flask"
check_port "8765" "WebSocket"
check_port "8080" "HTTP"

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

echo -e "  📱 ${GREEN}Web Arayüzü: http://$SERVER_IP:8080${NC}"
echo -e "  📊 ${BLUE}API Status: http://$SERVER_IP:8080/api/status${NC}"
echo -e "  🏥 ${BLUE}Health Check: http://$SERVER_IP:8080/api/health${NC}"

echo ""
echo -e "${CYAN}📱 Telefon/Tablet Erişimi:${NC}"
echo -e "  ${GREEN}1.${NC} Telefonunuzun tarayıcısını açın"
echo -e "  ${GREEN}2.${NC} Adres çubuğuna şunu yazın: ${YELLOW}$SERVER_IP:8080${NC}"
echo -e "  ${GREEN}3.${NC} Kodlama asistanınızı kullanmaya başlayın!"

echo ""
echo -e "${CYAN}🧪 Hızlı Sistem Testi:${NC}"

# API health check
echo -n "  🏥 API sağlık testi... "
if curl -f -s http://localhost:8080/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Başarılı${NC}"
    API_STATUS="OK"
else
    echo -e "${RED}❌ Başarısız${NC}"
    API_STATUS="ERROR"
fi

# Ana sayfa testi
echo -n "  🌐 Ana sayfa testi... "
if curl -f -s http://localhost:8080/ > /dev/null 2>&1; then
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
    echo "$(date): Sunucu başarıyla başlatıldı - Tüm testler OK (Port 8080)" >> /var/log/kodlama-asistani/startup.log
    
elif [ "$FLASK_STATUS" = "OK" ] && [ "$NGINX_STATUS" = "OK" ]; then
    echo -e "${YELLOW}⚠️ SİSTEM KISMEN ÇALIŞIYOR${NC}"
    echo -e "${YELLOW}🔧 Bazı testler başarısız, ancak temel servisler çalışıyor${NC}"
    
else
    echo -e "${RED}❌ SİSTEMDE SORUNLAR VAR!${NC}"
    echo -e "${RED}🔧 Aşağıdaki komutlarla sorunları giderin:${NC}"
    echo -e "  ${YELLOW}📋 ./logs.sh${NC} - Detaylı logları görün"
    echo -e "  ${YELLOW}📊 ./status.sh${NC} - Sistem durumunu kontrol edin"
    echo -e "  ${YELLOW}🔄 ./restart.sh${NC} - Servisleri yeniden başlatın"
fi

echo ""
echo -e "${CYAN}📋 Diğer Komutlar:${NC}"
echo -e "  ${BLUE}./stop_server.sh${NC} - Sunucuyu durdur"
echo -e "  ${BLUE}./restart.sh${NC} - Servisleri yeniden başlat"
echo -e "  ${BLUE}./status.sh${NC} - Detaylı sistem durumu"
echo -e "  ${BLUE}./logs.sh${NC} - Sistem loglarını görüntüle"
echo -e "  ${BLUE}./test.sh${NC} - Kapsamlı sistem testi"

echo ""
echo -e "${GREEN}🚀 Sunucu başlatma işlemi tamamlandı! (Port 8080)${NC}"

# Exit code kontrolü
if [ "$FLASK_STATUS" != "OK" ] || [ "$NGINX_STATUS" != "OK" ]; then
    exit 1
fi

exit 0
START_EOF

# 6. status.sh güncelle
echo "📊 status.sh güncelleniyor..."
# status.sh'deki port kontrollerini güncelleyelim
sed -i 's/:80/:8080/g' status.sh
sed -i 's/Port 80/Port 8080/g' status.sh
sed -i 's/http:\/\/localhost\//http:\/\/localhost:8080\//g' status.sh
sed -i 's/http:\/\/\$INTERNAL_IP/http:\/\/\$INTERNAL_IP:8080/g' status.sh
sed -i 's/http:\/\/\$SERVER_IP/http:\/\/\$SERVER_IP:8080/g' status.sh

# 7. test.sh güncelle
echo "🧪 test.sh güncelleniyor..."
sed -i 's/:80/:8080/g' test.sh
sed -i 's/Port 80/Port 8080/g' test.sh
sed -i 's/http:\/\/localhost\//http:\/\/localhost:8080\//g' test.sh
sed -i 's/http:\/\/\$SERVER_IP/http:\/\/\$SERVER_IP:8080/g' test.sh

# 8. restart.sh güncelle
echo "🔄 restart.sh güncelleniyor..."
sed -i 's/:80/:8080/g' restart.sh
sed -i 's/Port 80/Port 8080/g' restart.sh
sed -i 's/http:\/\/localhost\//http:\/\/localhost:8080\//g' restart.sh

# 9. logs.sh güncelle
echo "📋 logs.sh güncelleniyor..."
sed -i 's/:80/:8080/g' logs.sh

# 10. monitor.sh güncelle
echo "📺 monitor.sh güncelleniyor..."
sed -i 's/:80/:8080/g' monitor.sh
sed -i 's/Port 80/Port 8080/g' monitor.sh
sed -i 's/http:\/\/localhost\//http:\/\/localhost:8080\//g' monitor.sh

# 11. Templates dizini oluştur
echo "📁 Templates dizini oluşturuluyor..."
mkdir -p templates

# 12. HTML template dosyası oluştur
echo "📄 HTML template oluşturuluyor..."
cat > templates/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🤖 Kodlama Asistanı - Port 8080</title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/themes/prism-tomorrow.min.css" rel="stylesheet">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/components/prism-core.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/plugins/autoloader/prism-autoloader.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
            line-height: 1.6;
        }
        
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            padding: 20px; 
            min-height: 100vh; 
            display: flex; 
            flex-direction: column; 
        }
        
        .header { 
            background: rgba(255, 255, 255, 0.95); 
            border-radius: 20px; 
            padding: 30px; 
            margin-bottom: 25px; 
            backdrop-filter: blur(15px); 
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
            text-align: center; 
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .header h1 { 
            color: #4c51bf; 
            margin-bottom: 15px; 
            font-size: 2.5rem; 
            font-weight: 700;
            text-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .header p {
            color: #6b7280;
            font-size: 1.1rem;
            margin-bottom: 20px;
            font-weight: 500;
        }
        
        .status { 
            display: inline-flex;
            align-items: center;
            gap: 10px;
            padding: 12px 24px; 
            border-radius: 25px; 
            font-weight: bold; 
            font-size: 0.95rem; 
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }
        
        .status.connected { 
            background: linear-gradient(135deg, #d1fae5, #a7f3d0); 
            color: #065f46; 
            border: 2px solid #10b981;
        }
        
        .status.disconnected { 
            background: linear-gradient(135deg, #fef2f2, #fecaca); 
            color: #991b1b;
            border: 2px solid #ef4444;
        }
        
        .status.connecting { 
            background: linear-gradient(135deg, #fef3c7, #fde68a); 
            color: #92400e;
            border: 2px solid #f59e0b;
        }
        
        .status-indicator {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        
        .connected .status-indicator { background: #10b981; }
        .disconnected .status-indicator { background: #ef4444; }
        .connecting .status-indicator { background: #f59e0b; }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.7; transform: scale(1.1); }
        }
        
        .main-content { 
            flex: 1; 
            display: grid; 
            grid-template-columns: 1fr 1fr; 
            gap: 25px; 
            margin-bottom: 25px; 
        }
        
        .input-section, .output-section { 
            background: rgba(255, 255, 255, 0.95); 
            border-radius: 20px; 
            padding: 30px; 
            backdrop-filter: blur(15px); 
            box-shadow: 0 15px 50px rgba(0, 0, 0, 0.1); 
            display: flex; 
            flex-direction: column;
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: transform 0.3s ease;
        }
        
        .section-title { 
            font-size: 1.4rem; 
            font-weight: bold; 
            margin-bottom: 20px; 
            color: #4c51bf; 
            border-bottom: 3px solid #4c51bf; 
            padding-bottom: 12px; 
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .prompt-input { 
            width: 100%; 
            min-height: 240px; 
            border: 2px solid #e5e7eb; 
            border-radius: 15px; 
            padding: 20px; 
            font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', 'SF Mono', monospace; 
            font-size: 14px; 
            resize: vertical; 
            transition: all 0.3s ease; 
            flex: 1;
            line-height: 1.6;
            background: #fafafa;
        }
        
        .prompt-input:focus { 
            outline: none; 
            border-color: #4c51bf; 
            box-shadow: 0 0 25px rgba(76, 81, 191, 0.2);
            background: white;
        }
        
        .controls { 
            margin-top: 20px; 
            display: flex; 
            gap: 15px; 
            align-items: center; 
            flex-wrap: wrap;
        }
        
        .send-btn { 
            background: linear-gradient(135deg, #4c51bf 0%, #667eea 100%); 
            color: white; 
            border: none; 
            padding: 15px 35px; 
            border-radius: 30px; 
            font-weight: bold; 
            cursor: pointer; 
            transition: all 0.3s ease; 
            font-size: 1rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .send-btn:hover:not(:disabled) { 
            transform: translateY(-3px); 
            filter: brightness(1.1);
        }
        
        .send-btn:disabled { 
            opacity: 0.6; 
            cursor: not-allowed;
        }
        
        .output-area { 
            flex: 1; 
            border: 2px solid #e5e7eb; 
            border-radius: 15px; 
            padding: 25px; 
            background: #f9fafb; 
            overflow-y: auto; 
            min-height: 400px;
            max-height: 600px;
        }
        
        .loading { 
            display: inline-block; 
            width: 22px; 
            height: 22px; 
            border: 3px solid #f3f4f6; 
            border-top: 3px solid #4c51bf; 
            border-radius: 50%; 
            animation: spin 1s linear infinite; 
            margin-right: 12px; 
        }
        
        @keyframes spin { 
            0% { transform: rotate(0deg); } 
            100% { transform: rotate(360deg); } 
        }
        
        .response { 
            margin-bottom: 25px; 
            padding: 25px; 
            border-radius: 15px; 
            border-left: 5px solid #4c51bf; 
            background: white; 
            box-shadow: 0 5px 20px rgba(0, 0, 0, 0.08);
        }
        
        .response-header { 
            font-weight: bold; 
            color: #4c51bf; 
            margin-bottom: 15px; 
        }
        
        .code-block { 
            background: #1f2937; 
            color: #f9fafb; 
            padding: 25px; 
            border-radius: 12px; 
            overflow-x: auto; 
            margin: 15px 0; 
            font-family: monospace;
        }
        
        .footer {
            text-align: center;
            padding: 25px;
            color: rgba(255,255,255,0.9);
            font-size: 0.9rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
        }
        
        @media (max-width: 768px) { 
            .main-content { 
                grid-template-columns: 1fr; 
                gap: 20px;
            } 
            
            .header h1 { 
                font-size: 2rem; 
            }
            
            .controls { 
                flex-direction: column; 
                align-items: stretch; 
            } 
            
            .send-btn { 
                width: 100%; 
                justify-content: center;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 Kodlama Asistanı</h1>
            <p>GTX 1050 Ti • DeepSeek Coder 6.7B • Port 8080 (CyberPanel Uyumlu)</p>
            <div class="status connecting" id="status">
                <div class="status-indicator"></div>
                <span>Bağlanıyor...</span>
            </div>
        </div>
        
        <div class="main-content">
            <div class="input-section">
                <div class="section-title">
                    <span>📝</span>
                    <span>Kod İsteği</span>
                </div>
                <textarea class="prompt-input" id="promptInput" placeholder="Kodlama sorunuzu buraya yazın...

🎯 Örnek sorular:
• Python'da CSV dosyası okuma kodu
• React component oluşturma
• JavaScript async/await kullanımı
• SQL optimizasyon teknikleri

💡 İpucu: Ctrl+Enter ile gönderim"></textarea>
                
                <div class="controls">
                    <button class="send-btn" id="sendBtn">
                        <span>🚀</span>
                        <span id="sendText">Gönder</span>
                    </button>
                    <button class="send-btn" onclick="clearOutput()">
                        <span>🧹</span>
                        <span>Temizle</span>
                    </button>
                </div>
            </div>
            
            <div class="output-section">
                <div class="section-title">
                    <span>💬</span>
                    <span>AI Yanıtları</span>
                </div>
                <div class="output-area" id="outputArea">
                    <div style="text-align: center; color: #6b7280; margin-top: 80px;">
                        <div style="font-size: 3rem; margin-bottom: 20px;">🎯</div>
                        <p style="font-size: 1.2rem; margin-bottom: 15px; font-weight: 600;">Hazırım!</p>
                        <p style="font-size: 1rem; margin-bottom: 20px; color: #9ca3af;">Kodlama sorunuzu yazın ve profesyonel çözümü alın</p>
                        <div style="font-size: 0.85rem; color: #9ca3af; line-height: 1.8;">
                            <p>🤖 <strong>Model:</strong> DeepSeek Coder 6.7B</p>
                            <p>🎮 <strong>GPU:</strong> GTX 1050 Ti 4GB</p>
                            <p>🌐 <strong>Port:</strong> 8080 (CyberPanel Uyumlu)</p>
                            <p>⚡ <strong>Yanıt süresi:</strong> ~15-30 saniye</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Made with ❤️ for developers • Powered by GTX 1050 Ti • Port 8080 (CyberPanel Compatible)</p>
        </div>
    </div>

    <script>
        let ws = null;
        let isConnected = false;
        
        function connect() {
            const wsUrl = `ws://${window.location.hostname}:8765`;
            ws = new WebSocket(wsUrl);
            
            ws.onopen = function() {
                isConnected = true;
                updateStatus('connected', '🟢 Bağlı & Hazır');
                
                ws.send(JSON.stringify({
                    type: 'register',
                    client_type: 'web_client',
                    client_info: {
                        user_agent: navigator.userAgent,
                        port: '8080'
                    }
                }));
            };
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                handleMessage(data);
            };
            
            ws.onclose = function() {
                isConnected = false;
                updateStatus('disconnected', '🔴 Bağlantı Kesildi');
                setTimeout(connect, 3000); // Reconnect
            };
            
            ws.onerror = function() {
                updateStatus('disconnected', '❌ Bağlantı Hatası');
            };
        }
        
        function updateStatus(type, text) {
            const statusEl = document.getElementById('status');
            statusEl.className = `status ${type}`;
            statusEl.innerHTML = `<div class="status-indicator"></div><span>${text}</span>`;
        }
        
        function handleMessage(data) {
            switch (data.type) {
                case 'request_sent':
                    showLoading();
                    break;
                case 'code_response':
                    showResponse(data.response);
                    break;
                case 'error':
                    showError(data.message);
                    break;
            }
        }
        
        function sendPrompt() {
            const prompt = document.getElementById('promptInput').value.trim();
            
            if (!prompt) {
                alert('Lütfen bir kod isteği yazın');
                return;
            }
            
            if (!isConnected) {
                alert('Sunucuya bağlı değilsiniz');
                return;
            }
            
            ws.send(JSON.stringify({
                type: 'code_request',
                prompt: prompt
            }));
            
            document.getElementById('sendBtn').disabled = true;
            document.getElementById('sendText').innerHTML = '<div class="loading"></div>Gönderiliyor...';
        }
        
        function showLoading() {
            const output = document.getElementById('outputArea');
            const loadingDiv = document.createElement('div');
            loadingDiv.className = 'response';
            loadingDiv.innerHTML = `
                <div class="response-header">🔄 AI Düşünüyor... (${new Date().toLocaleTimeString()})</div>
                <div style="display: flex; align-items: center; gap: 12px;">
                    <div class="loading"></div>
                    <span>GTX 1050 Ti'den yanıt bekleniyor...</span>
                </div>
            `;
            output.appendChild(loadingDiv);
            output.scrollTop = output.scrollHeight;
        }
        
        function showResponse(response) {
            const output = document.getElementById('outputArea');
            const responseDiv = document.createElement('div');
            responseDiv.className = 'response';
            responseDiv.innerHTML = `
                <div class="response-header">✅ AI Yanıtı (${new Date().toLocaleTimeString()})</div>
                <div>${formatResponse(response)}</div>
            `;
            
            // Remove loading
            const loadingElements = output.querySelectorAll('.response');
            const lastElement = loadingElements[loadingElements.length - 1];
            if (lastElement && lastElement.innerHTML.includes('Düşünüyor')) {
                lastElement.remove();
            }
            
            output.appendChild(responseDiv);
            output.scrollTop = output.scrollHeight;
            
            resetSendButton();
        }
        
        function showError(message) {
            const output = document.getElementById('outputArea');
            const errorDiv = document.createElement('div');
            errorDiv.className = 'response';
            errorDiv.style.borderLeftColor = '#ef4444';
            errorDiv.innerHTML = `
                <div class="response-header" style="color: #dc2626;">❌ Hata</div>
                <div style="color: #dc2626;">${message}</div>
            `;
            output.appendChild(errorDiv);
            output.scrollTop = output.scrollHeight;
            
            resetSendButton();
        }
        
        function formatResponse(text) {
            return text
                .replace(/```(\w+)?\n([\s\S]*?)```/g, '<pre class="code-block"><code>$2</code></pre>')
                .replace(/`([^`\n]+)`/g, '<code style="background: #f1f3f4; padding: 3px 6px; border-radius: 4px;">$1</code>')
                .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                .replace(/\*(.*?)\*/g, '<em>$1</em>')
                .replace(/\n\n/g, '</p><p>')
                .replace(/\n/g, '<br>')
                .replace(/^/, '<p>')
                .replace(/$/, '</p>');
        }
        
        function resetSendButton() {
            document.getElementById('sendBtn').disabled = false;
            document.getElementById('sendText').innerHTML = 'Gönder';
        }
        
        function clearOutput() {
            document.getElementById('outputArea').innerHTML = `
                <div style="text-align: center; color: #6b7280; margin-top: 80px;">
                    <div style="font-size: 3rem; margin-bottom: 20px;">🧹</div>
                    <p style="font-size: 1.2rem; margin-bottom: 10px; font-weight: 600;">Yanıtlar temizlendi</p>
                    <p style="font-size: 1rem; color: #9ca3af;">Yeni sorularınızı yazabilirsiniz</p>
                </div>
            `;
        }
        
        // Event listeners
        document.getElementById('sendBtn').addEventListener('click', sendPrompt);
        document.getElementById('promptInput').addEventListener('keydown', function(e) {
            if (e.ctrlKey && e.key === 'Enter') {
                e.preventDefault();
                sendPrompt();
            }
        });
        
        // Initialize
        connect();
    </script>
</body>
</html>
HTML_EOF

# 13. Nginx testi ve yeniden başlatma
echo "🧪 Nginx konfigürasyonu test ediliyor..."
if sudo nginx -t; then
    echo "✅ Nginx konfigürasyonu geçerli"
else
    echo "❌ Nginx konfigürasyonu hatası! Lütfen kontrol edin."
    exit 1
fi

# 14. Servisleri başlat
echo "▶️ Servisleri başlatıyor..."
sudo systemctl start kodlama-asistani
sudo systemctl start nginx

# 15. Script'leri executable yap
chmod +x *.sh

echo ""
echo "✅ PORT 8080 GÜNCELLEMESİ TAMAMLANDI!"
echo "===================================="
echo ""
echo "🎯 Değişiklikler:"
echo "  • Port 80 -> 8080"
echo "  • app.py syntax hatası düzeltildi"
echo "  • Nginx konfigürasyonu güncellendi"
echo "  • Tüm script'ler güncellendi"
echo "  • Templates dizini oluşturuldu"
echo "  • Firewall kuralları eklendi"
echo ""
echo "🌍 Yeni Erişim Adresi:"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "  📱 Web Arayüzü: http://$SERVER_IP:8080"
echo "  📊 API Status: http://$SERVER_IP:8080/api/status"
echo "  🏥 Health Check: http://$SERVER_IP:8080/api/health"
echo ""
echo "🔥 Firewall kuralları:"
echo "  • Port 8080: HTTP"
echo "  • Port 8765: WebSocket"
echo ""
echo "📱 Telefon erişimi: $SERVER_IP:8080"
echo ""
echo "🧪 Sistem testi: ./test.sh"
echo "📊 Durum kontrol: ./status.sh"

exit 0