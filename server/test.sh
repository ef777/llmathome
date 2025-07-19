
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
