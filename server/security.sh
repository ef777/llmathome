
# security.sh
cat > security.sh << 'EOF'
#!/bin/bash
echo "🔒 Kodlama Asistanı Güvenlik Sıkılaştırma"
echo "========================================"

# Fail2ban kurulumu
echo "🛡️ Fail2ban kuruluyor..."
sudo apt update
sudo apt install -y fail2ban

# Fail2ban konfigürasyonu
sudo tee /etc/fail2ban/jail.local > /dev/null << 'FAIL2BAN_EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
FAIL2BAN_EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# UFW kurallarını sıkılaştır
echo "🔥 Firewall kuralları sıkılaştırılıyor..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Sadece gerekli portları aç
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Rate limiting
sudo ufw limit ssh

sudo ufw --force enable

echo "✅ Güvenlik sıkılaştırma tamamlandı!"
EOF
