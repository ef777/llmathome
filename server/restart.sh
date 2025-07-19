
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
