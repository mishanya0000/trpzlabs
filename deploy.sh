#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  echo "Будь ласка, запустіть через sudo: sudo ./deploy.sh"
  exit 1
fi

N=18
PORT=8000

echo "=== РОЗГОРТАННЯ ДЛЯ ВАРІАНТУ: N=$N (V2=1, V3=1, V5=4, PORT=$PORT) ==="

# Створення файлу з номером залікової
mkdir -p /home/student
echo "$N" > /home/student/gradebook
chmod 644 /home/student/gradebook

# Створення обов'язкових користувачів
create_user() {
  if ! id "$1" &>/dev/null; then
    useradd -m -s /bin/bash "$1"
    echo "$1:12345678" | chpasswd
    chage -d 0 "$1"
  fi
}
create_user "student"
create_user "teacher"
create_user "operator"

usermod -aG sudo student
usermod -aG sudo teacher

if ! id "app" &>/dev/null; then
  useradd -r -s /usr/sbin/nologin app
fi

# Налаштування sudo прав для operator
cat << 'SUDO' > /etc/sudoers.d/operator
operator ALL=(root) NOPASSWD: /usr/bin/systemctl start mywebapp.service, \
                             /usr/bin/systemctl stop mywebapp.service, \
                             /usr/bin/systemctl restart mywebapp.service, \
                             /usr/bin/systemctl status mywebapp.service, \
                             /usr/bin/systemctl reload nginx
SUDO
chmod 0440 /etc/sudoers.d/operator

# Переміщення файлів проєкту в робочу директорію
mkdir -p /opt/mywebapp
cp -r app /opt/mywebapp/
cp migrate.py /opt/mywebapp/
cp requirements.txt /opt/mywebapp/

# Створення віртуального середовища Python
python3 -m venv /opt/mywebapp/venv
/opt/mywebapp/venv/bin/pip install --upgrade pip

# Інструкція pip НЕ намагатися збирати бінарники (компілювати), а ставити чистий Python код
export PURE_PYTHON=1
/opt/mywebapp/venv/bin/pip install --no-binary=:all: -r /opt/mywebapp/requirements.txt

chown -R app:app /opt/mywebapp

# Створення Systemd Socket Activation файлів
cat << 'UNIT' > /etc/systemd/system/mywebapp.socket
[Unit]
Description=Socket for My Web Application

[Socket]
ListenStream=127.0.0.1:8000

[Install]
WantedBy=sockets.target
UNIT

cat << 'UNIT' > /etc/systemd/system/mywebapp.service
[Unit]
Description=My Web Application Service
Requires=mywebapp.socket
After=network.target

[Service]
User=app
Group=app
WorkingDirectory=/opt/mywebapp
ExecStartPre=/opt/mywebapp/venv/bin/python /opt/mywebapp/migrate.py
ExecStart=/opt/mywebapp/venv/bin/uvicorn app.main:app --fd 0
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

# Перезапуск сервісів та активація сокету
systemctl daemon-reload
systemctl enable --now mywebapp.socket
systemctl restart mywebapp.service 2>/dev/null || systemctl start mywebapp.service

# Конфігурація зворотного проксі Nginx
cat << 'NGINX' > /etc/nginx/sites-available/default
server {
    listen 80;
    server_name localhost;
    access_log /var/log/nginx/mywebapp_access.log;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /health/ {
        deny all;
        return 403;
    }
}
NGINX

nginx -t && systemctl restart nginx

# Блокування дефолтного користувача системи (vboxuser) за вимогою лабораторної
echo "Блокування стандартного користувача vboxuser..."
passwd -l vboxuser

echo "=== АВТОМАТИЗАЦІЮ РОЗГОРТАННЯ ЗАВЕРШЕНО УСПІШНО ==="
