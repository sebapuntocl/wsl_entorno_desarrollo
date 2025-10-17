#!/bin/bash
# =========================================================
# Script Entorno WSL - Apache2 + PHP (Full) + Node/Python (Básico)
# PHP con SSL, Mailpit, manejo de errores
# Node.js y Python: solo instalación
# =========================================================

set -e  # Detener ejecución si hay errores
trap 'echo "❌ Error en línea $LINENO. Revisa los logs arriba."' ERR

# Variable dinámica para el usuario actual de WSL
USER_NAME=$(whoami)
WEB_ROOT="/home/${USER_NAME}/proyectos/php"

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# Función para mensajes
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Verificar que estamos en WSL
if ! grep -qi microsoft /proc/version; then
    log_warn "Este script está diseñado para WSL"
    read -p "¿Continuar de todos modos? (s/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Ss]$ ]] && exit 1
fi

# ----------------------------------------------------------------
# 1️⃣ Actualizar Ubuntu
# ----------------------------------------------------------------
echo "🔄 Actualizando repositorios y paquetes del sistema..."
sudo apt update -y && sudo apt upgrade -y
log_info "Sistema actualizado"

# ----------------------------------------------------------------
# 2️⃣ Instalación de Git (esencial)
# ----------------------------------------------------------------
echo "📦 Instalando Git..."
sudo apt install -y git
log_info "Git instalado: $(git --version)"

# ----------------------------------------------------------------
# 3️⃣ Instalación BÁSICA de Node.js (sin PM2)
# ----------------------------------------------------------------
echo "🟢 Instalando Node.js LTS (solo instalación básica)..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs build-essential
    log_info "Node.js $(node -v) instalado"
    log_info "npm $(npm -v) instalado"
else
    log_warn "Node.js ya está instalado: $(node -v)"
fi

# ----------------------------------------------------------------
# 4️⃣ Instalación BÁSICA de Python (sin venv ni frameworks)
# ----------------------------------------------------------------
echo "🐍 Instalando Python 3 y pip (solo instalación básica)..."
sudo apt install -y python3 python3-pip python3-venv
log_info "Python $(python3 --version) instalado"
log_info "pip $(pip3 --version | awk '{print $2}') instalado"

# ----------------------------------------------------------------
# 5️⃣ Instalación COMPLETA de PHP con todas las extensiones
# ----------------------------------------------------------------
echo "🐘 Instalando PHP y extensiones completas..."
sudo apt install -y \
    php php-cli php-fpm php-mbstring php-xml php-curl \
    php-mysql php-pgsql php-zip php-gd php-intl \
    php-bcmath php-soap php-redis php-sqlite3 unzip curl

PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;")
log_info "PHP ${PHP_VERSION} instalado"

# Instalar Composer
if ! command -v composer &> /dev/null; then
    echo "📦 Instalando Composer..."
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
    sudo chmod +x /usr/local/bin/composer
    log_info "Composer $(composer --version | awk '{print $3}') instalado"
else
    log_warn "Composer ya está instalado"
fi

# ----------------------------------------------------------------
# 5️⃣.1️⃣ Instalación y Configuración de Xdebug
# ----------------------------------------------------------------
echo "🐞 Instalando Xdebug para debugging..."
sudo apt install -y php${PHP_VERSION}-xdebug

# Configurar Xdebug para VS Code
sudo tee /etc/php/${PHP_VERSION}/mods-available/xdebug.ini > /dev/null <<EOF
zend_extension=xdebug.so
xdebug.mode=debug
xdebug.start_with_request=yes
xdebug.client_port=9003
xdebug.client_host=localhost
xdebug.log=/tmp/xdebug.log
xdebug.idekey=VSCODE
EOF

log_info "Xdebug configurado para VS Code (puerto 9003)"

# ----------------------------------------------------------------
# 5️⃣.2️⃣ Instalación de SQLite
# ----------------------------------------------------------------
echo "💾 Instalando SQLite..."
sudo apt install -y sqlite3 libsqlite3-dev
log_info "SQLite $(sqlite3 --version | awk '{print $1}') instalado"

# ----------------------------------------------------------------
# 6️⃣ Instalación de Mailpit (Captura de Emails) - CORREGIDO
# ----------------------------------------------------------------
echo "📧 Instalando Mailpit para captura de emails..."
MAILPIT_VERSION="v1.20.5"

# Descargar e instalar Mailpit
if [ ! -f /usr/local/bin/mailpit ]; then
    wget -q https://github.com/axllent/mailpit/releases/download/${MAILPIT_VERSION}/mailpit-linux-amd64.tar.gz
    sudo tar -xzf mailpit-linux-amd64.tar.gz -C /usr/local/bin/
    rm mailpit-linux-amd64.tar.gz
    sudo chmod +x /usr/local/bin/mailpit
    log_info "Mailpit binario instalado"
else
    log_warn "Mailpit ya está instalado"
fi

# Configurar PHP para usar Mailpit (CORRECCIÓN CRÍTICA)
# Mailpit usa el comando "sendmail" sin el flag -S
sudo tee /etc/php/${PHP_VERSION}/mods-available/mailpit.ini > /dev/null <<'EOF'
; Configuración para Mailpit
sendmail_path = "/usr/local/bin/mailpit sendmail -t --smtp-addr localhost:1025"
EOF

# Activar configuración en PHP-FPM y CLI
sudo ln -sf /etc/php/${PHP_VERSION}/mods-available/mailpit.ini /etc/php/${PHP_VERSION}/fpm/conf.d/99-mailpit.ini
sudo ln -sf /etc/php/${PHP_VERSION}/mods-available/mailpit.ini /etc/php/${PHP_VERSION}/cli/conf.d/99-mailpit.ini

# Reiniciar PHP-FPM para aplicar cambios
sudo service php${PHP_VERSION}-fpm restart

log_info "Mailpit configurado - UI: http://localhost:8025"

# Nota: Mailpit se iniciará más adelante en la sección de servicios
# http://localhost:8025/ o http://localhost/test-email.php

# ----------------------------------------------------------------
# 7️⃣ Instalación de MySQL
# ----------------------------------------------------------------
echo "🐬 Instalando MySQL Server..."
sudo apt install -y mysql-server

sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
CREATE USER '${USER_NAME}'@'%' IDENTIFIED BY 'pelota';
GRANT ALL PRIVILEGES ON *.* TO '${USER_NAME}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

sudo sed -i "s/bind-address\s*=.*$/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
sudo service mysql restart
log_info "MySQL configurado - root:root | ${USER_NAME}:pelota"

# ----------------------------------------------------------------
# 8️⃣ Instalación de PostgreSQL
# ----------------------------------------------------------------
echo "🐘 Instalando PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

PG_VER=$(ls /etc/postgresql/ | sort -V | tail -n 1)
sudo -u postgres psql <<EOF
ALTER USER postgres WITH PASSWORD 'root';
CREATE USER ${USER_NAME} WITH PASSWORD 'pelota';
CREATE DATABASE ${USER_NAME} OWNER ${USER_NAME};
EOF

sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/$PG_VER/main/postgresql.conf
echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$PG_VER/main/pg_hba.conf
sudo service postgresql restart
log_info "PostgreSQL configurado - postgres:root | ${USER_NAME}:pelota"

# ----------------------------------------------------------------
# 9️⃣ Instalación de Redis
# ----------------------------------------------------------------
echo "🔴 Instalando Redis..."
sudo apt install -y redis-server
sudo sed -i "s/^supervised no/supervised systemd/" /etc/redis/redis.conf
sudo service redis-server restart
log_info "Redis instalado y corriendo"

# ----------------------------------------------------------------
# 🔟 Instalación y Configuración de Apache2
# ----------------------------------------------------------------
echo "🌐 Instalando Apache2..."
sudo apt install -y apache2 libapache2-mod-fcgid

# Habilitar módulos necesarios
sudo a2enmod proxy proxy_http proxy_fcgi proxy_wstunnel rewrite \
             actions alias setenvif ssl headers
sudo a2enconf php${PHP_VERSION}-fpm

# Crear estructura de proyectos
mkdir -p ~/proyectos/{php,node,python}
log_info "Estructura de carpetas creada en ~/proyectos/"

# Configurar permisos
sudo chmod o+x /home/$USER_NAME
sudo chown -R ${USER_NAME}:www-data ~/proyectos
sudo chmod -R 775 ~/proyectos

# ----------------------------------------------------------------
# 🔟.1️⃣ Instalación de Supervisor
# ----------------------------------------------------------------
echo "👁️ Instalando Supervisor para Laravel queues/workers..."
sudo apt install -y supervisor

# Crear directorio para configuraciones de Laravel
sudo mkdir -p /etc/supervisor/conf.d

# Crear configuración base para Laravel (el usuario la personaliza después)
sudo tee /etc/supervisor/conf.d/laravel-worker-example.conf > /dev/null <<EOF
; Ejemplo de configuración para Laravel Queue Worker
; Copia y edita este archivo para tus proyectos
;
; [program:laravel-worker]
; process_name=%(program_name)s_%(process_num)02d
; command=php ${WEB_ROOT}/tu-proyecto/artisan queue:work --sleep=3 --tries=3 --max-time=3600
; autostart=true
; autorestart=true
; stopasgroup=true
; killasgroup=true
; user=${USER_NAME}
; numprocs=1
; redirect_stderr=true
; stdout_logfile=${WEB_ROOT}/tu-proyecto/storage/logs/worker.log
; stopwaitsecs=3600
EOF

sudo service supervisor start
log_info "Supervisor instalado - Config ejemplo en /etc/supervisor/conf.d/"

# ----------------------------------------------------------------
# 1️⃣1️⃣ Configuración de SSL Auto-firmado
# ----------------------------------------------------------------
echo "🔒 Generando certificado SSL auto-firmado..."
sudo mkdir -p /etc/apache2/ssl

if [ ! -f /etc/apache2/ssl/localhost.crt ]; then
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/apache2/ssl/localhost.key \
        -out /etc/apache2/ssl/localhost.crt \
        -subj "/C=CL/ST=Coquimbo/L=Coquimbo/O=Dev/CN=localhost"
    log_info "Certificado SSL creado"
else
    log_warn "Certificado SSL ya existe"
fi

# ----------------------------------------------------------------
# 1️⃣2️⃣ Virtual Host HTTP (Puerto 80)
# ----------------------------------------------------------------
echo "📝 Configurando Virtual Host HTTP..."
sudo tee /etc/apache2/sites-available/dev.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName localhost

    DocumentRoot ${WEB_ROOT}

    <Directory ${WEB_ROOT}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Configuración PHP-FPM
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost"
    </FilesMatch>

    <IfModule dir_module>
        DirectoryIndex index.php index.html
    </IfModule>

    # Logs
    ErrorLog \${APACHE_LOG_DIR}/dev_error.log
    CustomLog \${APACHE_LOG_DIR}/dev_access.log combined
</VirtualHost>
EOF

# ----------------------------------------------------------------
# 1️⃣3️⃣ Virtual Host HTTPS (Puerto 443)
# ----------------------------------------------------------------
echo "📝 Configurando Virtual Host HTTPS..."
sudo tee /etc/apache2/sites-available/dev-ssl.conf > /dev/null <<EOF
<VirtualHost *:443>
    ServerName localhost

    DocumentRoot ${WEB_ROOT}

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/localhost.crt
    SSLCertificateKeyFile /etc/apache2/ssl/localhost.key

    <Directory ${WEB_ROOT}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Configuración PHP-FPM
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost"
    </FilesMatch>

    <IfModule dir_module>
        DirectoryIndex index.php index.html
    </IfModule>

    # Headers de seguridad
    Header always set Strict-Transport-Security "max-age=31536000"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"

    # Logs
    ErrorLog \${APACHE_LOG_DIR}/dev_ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/dev_ssl_access.log combined
</VirtualHost>
EOF

# Activar sitios
sudo a2dissite 000-default.conf 2>/dev/null || true
sudo a2ensite dev.conf dev-ssl.conf

# ----------------------------------------------------------------
# 1️⃣4️⃣ Iniciar servicios
# ----------------------------------------------------------------
echo "🚀 Iniciando servicios..."
sudo service php${PHP_VERSION}-fpm start
sudo service apache2 restart
sudo service mysql start
sudo service postgresql start
sudo service redis-server start
sudo service supervisor start

# Iniciar Mailpit en background
nohup mailpit > /dev/null 2>&1 &
log_info "Mailpit corriendo en background"

# Verificar servicios
echo ""
echo "🔍 Verificando servicios..."
sudo service php${PHP_VERSION}-fpm status | grep -q "active (running)" && log_info "PHP-FPM activo" || log_error "PHP-FPM no está corriendo"
sudo service apache2 status | grep -q "active (running)" && log_info "Apache2 activo" || log_error "Apache2 no está corriendo"
sudo service mysql status | grep -q "active (running)" && log_info "MySQL activo" || log_error "MySQL no está corriendo"
sudo service postgresql status | grep -q "active" && log_info "PostgreSQL activo" || log_error "PostgreSQL no está corriendo"
sudo service redis-server status | grep -q "active (running)" && log_info "Redis activo" || log_error "Redis no está corriendo"
sudo service supervisor status | grep -q "active (running)" && log_info "Supervisor activo" || log_error "Supervisor no está corriendo"

# ----------------------------------------------------------------
# 1️⃣5️⃣ Crear archivo de prueba PHP
# ----------------------------------------------------------------
echo "📄 Creando archivo de prueba..."
cat > ${WEB_ROOT}/index.php <<'PHPEOF'
<?php
// Test completo del entorno
phpinfo();
?>
PHPEOF

cat > ${WEB_ROOT}/test-email.php <<'PHPEOF'
<?php
$to = "test@example.com";
$subject = "Test desde PHP";
$message = "Este es un email de prueba capturado por Mailpit";
$headers = "From: desarrollo@localhost\r\n" .
           "Reply-To: desarrollo@localhost\r\n" .
           "X-Mailer: PHP/" . phpversion();

if (mail($to, $subject, $message, $headers)) {
    echo "✅ Email enviado correctamente<br>";
    echo "👉 Revisa Mailpit en: <a href='http://localhost:8025'>http://localhost:8025</a>";
} else {
    echo "❌ Error al enviar email";
}
PHPEOF

cat > ${WEB_ROOT}/test-xdebug.php <<'PHPEOF'
<?php
echo "<h1>🐞 Test Xdebug</h1>";

if (extension_loaded('xdebug')) {
    echo "<p style='color: green;'>✅ Xdebug está instalado y activo</p>";
    echo "<h3>Configuración:</h3>";
    echo "<pre>";
    echo "Modo: " . ini_get('xdebug.mode') . "\n";
    echo "Puerto: " . ini_get('xdebug.client_port') . "\n";
    echo "Host: " . ini_get('xdebug.client_host') . "\n";
    echo "</pre>";
    
    echo "<h3>Para usar en VS Code:</h3>";
    echo "<ol>";
    echo "<li>Instala la extensión 'PHP Debug' de Xdebug</li>";
    echo "<li>Agrega un breakpoint en tu código (click en el margen izquierdo)</li>";
    echo "<li>Presiona F5 o usa 'Run > Start Debugging'</li>";
    echo "<li>Recarga esta página</li>";
    echo "</ol>";
    
    $test_var = "Pon un breakpoint en la siguiente línea";
    $array_test = array('laravel' => 'framework', 'php' => 'lenguaje');
    
    echo "<p>Variables de prueba creadas. Pon un breakpoint y recarga la página.</p>";
} else {
    echo "<p style='color: red;'>❌ Xdebug NO está instalado</p>";
}
PHPEOF

cat > ${WEB_ROOT}/test-sqlite.php <<'PHPEOF'
<?php
echo "<h1>💾 Test SQLite</h1>";

try {
    $db = new PDO('sqlite::memory:');
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $db->exec("CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT,
        email TEXT
    )");
    
    $db->exec("INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com')");
    $db->exec("INSERT INTO users (name, email) VALUES ('Jane Smith', 'jane@example.com')");
    
    $stmt = $db->query("SELECT * FROM users");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<p style='color: green;'>✅ SQLite funciona correctamente</p>";
    echo "<h3>Usuarios en la base de datos:</h3>";
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>ID</th><th>Nombre</th><th>Email</th></tr>";
    foreach ($users as $user) {
        echo "<tr>";
        echo "<td>" . $user['id'] . "</td>";
        echo "<td>" . $user['name'] . "</td>";
        echo "<td>" . $user['email'] . "</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    echo "<p><strong>SQLite version:</strong> " . $db->query('SELECT sqlite_version()')->fetch()[0] . "</p>";
    
} catch (PDOException $e) {
    echo "<p style='color: red;'>❌ Error: " . $e->getMessage() . "</p>";
}
PHPEOF

chmod 644 ${WEB_ROOT}/*.php

# ----------------------------------------------------------------
# 1️⃣6️⃣ Script de auto-inicio
# ----------------------------------------------------------------
echo "⚙️ Creando script de auto-inicio..."
AUTO_START_SCRIPT=~/start_dev_services.sh

tee $AUTO_START_SCRIPT > /dev/null <<EOF_SCRIPT
#!/bin/bash
# Script de auto-inicio para WSL

echo "🚀 Iniciando servicios de desarrollo..."

# Detectar versión de PHP automáticamente
PHP_VER=\$(php -r "echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;" 2>/dev/null || echo "8.1")

sudo service mysql start
sudo service postgresql start
sudo service redis-server start
sudo service php\${PHP_VER}-fpm start
sudo service apache2 start
sudo service supervisor start

# Iniciar Mailpit si no está corriendo
if ! pgrep -x "mailpit" > /dev/null; then
    nohup mailpit > /dev/null 2>&1 &
    echo "📧 Mailpit iniciado"
fi

echo "✅ Servicios iniciados correctamente"
echo "📌 PHP \${PHP_VER}-fpm activo"
EOF_SCRIPT

chmod +x $AUTO_START_SCRIPT
grep -qxF "$AUTO_START_SCRIPT" ~/.bashrc || echo "$AUTO_START_SCRIPT" >> ~/.bashrc

# ----------------------------------------------------------------
# 1️⃣7️⃣ Mensajes finales
# ----------------------------------------------------------------
WSL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "======================================================"
echo "✅ ENTORNO DE DESARROLLO CONFIGURADO"
echo "======================================================"
echo ""
echo "📂 ESTRUCTURA DE CARPETAS:"
echo "   ~/proyectos/php/     ← Tus proyectos PHP"
echo "   ~/proyectos/node/    ← Tus proyectos Node.js"
echo "   ~/proyectos/python/  ← Tus proyectos Python"
echo ""
echo "🌐 ACCESO WEB:"
echo "   HTTP:  http://localhost/"
echo "   HTTPS: https://localhost/ (certificado auto-firmado)"
echo "   Mailpit: http://localhost:8025"
echo ""
echo "🔧 SOFTWARE INSTALADO:"
echo "   PHP ${PHP_VERSION} + Composer + Xdebug"
echo "   Node.js $(node -v)"
echo "   Python $(python3 --version | awk '{print $2}')"
echo "   MySQL (root:root | ${USER_NAME}:pelota)"
echo "   PostgreSQL (postgres:root | ${USER_NAME}:pelota)"
echo "   Redis"
echo "   SQLite $(sqlite3 --version | awk '{print $1}')"
echo "   Supervisor (para Laravel queues)"
echo ""
echo "📧 TEST DE EMAIL:"
echo "   Abre: http://localhost/test-email.php"
echo "   Revisa inbox: http://localhost:8025"
echo ""
echo "🐞 TEST DE XDEBUG:"
echo "   Abre: http://localhost/test-xdebug.php"
echo "   Instrucciones para VS Code incluidas"
echo ""
echo "💾 TEST DE SQLITE:"
echo "   Abre: http://localhost/test-sqlite.php"
echo ""
echo "👁️ SUPERVISOR (Laravel Queues):"
echo "   Config ejemplo: /etc/supervisor/conf.d/laravel-worker-example.conf"
echo "   Comandos:"
echo "     - Ver status: sudo supervisorctl status"
echo "     - Recargar configs: sudo supervisorctl reread && sudo supervisorctl update"
echo "     - Reiniciar worker: sudo supervisorctl restart laravel-worker:*"
echo ""
echo "🔍 COMANDOS ÚTILES:"
echo "   Logs Apache: sudo tail -f /var/log/apache2/dev_error.log"
echo "   Estado PHP-FPM: sudo service php${PHP_VERSION}-fpm status"
echo "   Reiniciar Apache: sudo service apache2 restart"
echo "   Ver emails: mailpit (accede a http://localhost:8025)"
echo ""
echo "🔒 NOTA SOBRE SSL:"
echo "   Chrome/Edge mostrará advertencia de seguridad"
echo "   Haz clic en 'Avanzado' → 'Continuar a localhost'"
echo ""
echo "⚠️  PROXY WINDOWS (para clientes DB desde Windows):"
echo "   Ejecuta en PowerShell como Administrador:"
echo "   netsh interface portproxy add v4tov4 listenport=3306 listenaddress=127.0.0.1 connectport=3306 connectaddress=$WSL_IP"
echo "   netsh interface portproxy add v4tov4 listenport=5432 listenaddress=127.0.0.1 connectport=5432 connectaddress=$WSL_IP"
echo ""
echo "======================================================"
echo "    📌 AUTO-INICIO DE SERVICIOS:"
echo "    setup.sh"
echo "    chmod +x setup.sh"
echo "   ./setup.sh"
echo ""
echo "======================================================"
echo "🎯 PRUEBA TU ENTORNO:"
echo "   1. Abre http://localhost/ (deberías ver phpinfo)"
echo "   2. Abre https://localhost/ (prueba SSL)"
echo "   3. Abre http://localhost/test-email.php (prueba Mailpit)"
echo "   4. Abre http://localhost/test-xdebug.php (verifica Xdebug)"
echo "   5. Abre http://localhost/test-sqlite.php (verifica SQLite)"
echo "======================================================"
echo ""
echo "📚 CONFIGURACIÓN VS CODE PARA XDEBUG:"
echo "   Crea .vscode/launch.json en tu proyecto con:"
echo '   {'
echo '     "version": "0.2.0",'
echo '     "configurations": [{'
echo '       "name": "Listen for Xdebug",'
echo '       "type": "php",'
echo '       "request": "launch",'
echo '       "port": 9003,'
echo '       "pathMappings": {'
echo "         \"/home/${USER_NAME}/proyectos/php\": \"\${workspaceFolder}\""
echo '       }'
echo '     }]'
echo '   }'
echo "======================================================"