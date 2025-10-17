# 🚀 WSL Development Environment Setup

Script automatizado para configurar un entorno de desarrollo completo en WSL (Windows Subsystem for Linux) con Apache2, PHP, MySQL, PostgreSQL, Redis, Node.js y Python.

## 📋 Descripción

Este script bash configura automáticamente un entorno de desarrollo full-stack en WSL Ubuntu, ideal para desarrollo web moderno con Laravel, Symfony, y otros frameworks PHP, además de proyectos Node.js y Python.

## ✨ Características

### 🐘 PHP (Configuración Completa)
- PHP 8.x con PHP-FPM
- Composer (gestor de dependencias)
- Xdebug configurado para VS Code (puerto 9003)
- Extensiones: mbstring, xml, curl, mysql, pgsql, zip, gd, intl, bcmath, soap, redis
- Mailpit para captura de emails de desarrollo

### 🌐 Servidor Web
- Apache2 con módulos: proxy, rewrite, ssl, headers
- Virtual Hosts HTTP (puerto 80) y HTTPS (puerto 443)
- Certificado SSL auto-firmado para desarrollo local
- PHP-FPM con socket Unix para mejor rendimiento

### 🗄️ Bases de Datos
- **MySQL**: Usuario root (root/root) y usuario personalizado
- **PostgreSQL**: Usuario postgres (postgres/root) y usuario personalizado
- **Redis**: Cache y sessions

### 📧 Testing de Emails
- Mailpit: Captura todos los emails enviados desde PHP
- Interfaz web en `http://localhost:8025`
- No envía emails reales (perfecto para desarrollo)

### 🟢 Node.js (Instalación Básica)
- Node.js LTS
- npm
- build-essential

### 🐍 Python (Instalación Básica)
- Python 3
- pip3
- python3-venv

### 👁️ Supervisor
- Gestor de procesos para Laravel queues/workers
- Configuración de ejemplo incluida

### ⚙️ Auto-inicio
- Script que inicia todos los servicios automáticamente al abrir WSL
- Se ejecuta cada vez que abres tu terminal

## 📦 Requisitos

- Windows 10/11 con WSL2 habilitado
- Ubuntu instalado desde Microsoft Store (22.04 o 24.04 recomendado)
- Al menos 4GB de espacio libre en disco

## 🚀 Instalación

### 1. Clonar el repositorio
```bash
git clone https://github.com/sebapuntocl/wsl-dev-setup.git
cd wsl-dev-setup
```

### 2. Dar permisos de ejecución
```bash
chmod +x setup_dev.sh
```

### 3. Ejecutar el script
```bash
./setup_dev.sh
```

El script tardará aproximadamente 10-15 minutos en completarse.

## 📂 Estructura de Proyectos

El script crea automáticamente la siguiente estructura:
```
~/proyectos/
├── php/         # Proyectos PHP (Laravel, Symfony, etc.)
├── node/        # Proyectos Node.js
└── python/      # Proyectos Python
```

El directorio `~/proyectos/php/` está configurado como DocumentRoot de Apache.

## 🌐 Acceso a Servicios

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| Apache HTTP | http://localhost/ | - |
| Apache HTTPS | https://localhost/ | (certificado auto-firmado) |
| Mailpit UI | http://localhost:8025 | - |
| MySQL | localhost:3306 | root/root o usuario/pelota |
| PostgreSQL | localhost:5432 | postgres/root o usuario/pelota |
| Redis | localhost:6379 | - |

## 🧪 Páginas de Prueba

Después de la instalación, accede a estas URLs para verificar:

- http://localhost/ - PHPInfo completo
- http://localhost/test-email.php - Prueba de envío de emails con Mailpit
- http://localhost/test-xdebug.php - Verificación de Xdebug

## 🐞 Configuración de Xdebug para VS Code

Crea `.vscode/launch.json` en tu proyecto:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Listen for Xdebug",
      "type": "php",
      "request": "launch",
      "port": 9003,
      "pathMappings": {
        "/home/TU_USUARIO/proyectos/php": "${workspaceFolder}"
      }
    }
  ]
}
```

**Nota**: Reemplaza `TU_USUARIO` con tu nombre de usuario de WSL.

## 👁️ Supervisor para Laravel Queues

Configuración de ejemplo en: `/etc/supervisor/conf.d/laravel-worker-example.conf`

### Comandos útiles:
```bash
# Ver status de workers
sudo supervisorctl status

# Recargar configuraciones
sudo supervisorctl reread && sudo supervisorctl update

# Reiniciar worker específico
sudo supervisorctl restart laravel-worker:*

# Ver logs
sudo supervisorctl tail -f laravel-worker
```

## 🔧 Comandos Útiles
```bash
# Iniciar todos los servicios manualmente
~/start_dev_services.sh

# Ver logs de Apache
sudo tail -f /var/log/apache2/dev_error.log

# Estado de servicios
sudo service apache2 status
sudo service php8.x-fpm status
sudo service mysql status
sudo service postgresql status
sudo service redis-server status

# Reiniciar Apache
sudo service apache2 restart

# Reiniciar PHP-FPM
sudo service php8.x-fpm restart
```

## 🪟 Acceso desde Windows

### Conectar clientes de Base de Datos desde Windows

Ejecuta en PowerShell como Administrador:
```powershell
# Obtener IP de WSL
wsl hostname -I

# Crear proxy para MySQL
netsh interface portproxy add v4tov4 listenport=3306 listenaddress=127.0.0.1 connectport=3306 connectaddress=IP_WSL

# Crear proxy para PostgreSQL
netsh interface portproxy add v4tov4 listenport=5432 listenaddress=127.0.0.1 connectport=5432 connectaddress=IP_WSL
```

Luego conecta desde herramientas como TablePlus, DBeaver, etc. usando `localhost`.

## 🔒 Nota sobre SSL

El certificado SSL es auto-firmado, por lo que tu navegador mostrará una advertencia de seguridad. Esto es normal para desarrollo local.

Para continuar:
1. Haz clic en "Avanzado"
2. Selecciona "Continuar a localhost"

## 🐛 Solución de Problemas

### Apache no inicia
```bash
# Ver errores de configuración
sudo apache2ctl configtest

# Ver logs detallados
sudo journalctl -xeu apache2.service
```

### PHP no ejecuta archivos
```bash
# Verificar que PHP-FPM esté corriendo
sudo service php8.x-fpm status

# Reiniciar PHP-FPM
sudo service php8.x-fpm restart
```

### Mailpit no captura emails
```bash
# Verificar que Mailpit esté corriendo
pgrep mailpit

# Ver configuración PHP
php -i | grep sendmail_path

# Reiniciar Mailpit
pkill mailpit
nohup mailpit > /dev/null 2>&1 &
```

## 🔄 Actualización de Servicios
```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Actualizar Composer
sudo composer self-update

# Actualizar npm
sudo npm install -g npm@latest
```

## 📝 Personalización

### Cambiar puerto de Apache

Edita `/etc/apache2/sites-available/dev.conf` o `dev-ssl.conf` y cambia:
```apache
<VirtualHost *:80>  # Cambiar 80 por otro puerto
```

Luego:
```bash
sudo service apache2 restart
```

### Agregar más extensiones PHP
```bash
sudo apt install php8.x-EXTENSION
sudo service php8.x-fpm restart
```

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 👨‍💻 Autor

Sebastian Sotelo

## 🙏 Agradecimientos

- Comunidad de WSL
- Documentación de Apache, PHP y MySQL
- Axllent por [Mailpit](https://github.com/axllent/mailpit)

---
