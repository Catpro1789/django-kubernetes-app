#!/usr/bin/env bash
set -e

VAULT_DIR="docker/vault"

# Проверка наличия Docker
echo "=== Проверка наличия Docker ==="
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker не найден — устанавливаю..."
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
fi

# Проверка Docker Compose
echo "=== Проверка наличия Docker Compose ==="
if ! docker compose version >/dev/null 2>&1; then
    echo "Устанавливаю docker-compose-plugin..."
    sudo apt install -y docker-compose-plugin
fi

# Проверка доступа к Docker
echo "=== Проверка доступа к Docker daemon ==="
if ! docker ps >/dev/null 2>&1; then
    echo "⚠ Нет прав на доступ к Docker. Будем использовать sudo..."
    DOCKER_CMD="sudo docker"
else
    DOCKER_CMD="docker"
fi

# Создание каталога Vault
echo "=== Создание каталога Vault ==="
mkdir -p "$VAULT_DIR"

# Создание docker-compose.yml
echo "=== Создание docker-compose.yml ==="
cat > "$VAULT_DIR/docker-compose.yml" <<EOF
services:
  vault:
    image: hashicorp/vault:1.15
    container_name: vault
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: "root"
      VAULT_DEV_LISTEN_ADDRESS: "0.0.0.0:8200"
    cap_add:
      - IPC_LOCK
    command: "server -dev"
    volumes:
      - ./vault-data:/vault/data
EOF

# Запуск Vault
echo "=== Запуск Vault ==="
$DOCKER_CMD compose -f "$VAULT_DIR/docker-compose.yml" up -d

echo "=== Ожидание запуска Vault... ==="
sleep 5

# Проверка статуса
echo "=== Проверка статуса Vault ==="
curl -s http://127.0.0.1:8200/v1/sys/health | jq || true

# Экспорт VAULT_ADDR и root токена
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

# Создание базовой структуры секретов
echo "=== Создание базовой структуры секретов ==="
vault secrets enable -path=django kv-v2 || true
vault kv put django/app \
    DB_NAME="myapp" \
    DB_USER="django" \
    DEBUG="False"

# Получение тестового секрета
echo "=== Получение тестового секрета ==="
vault kv get django/app || true

echo
echo "=== Vault успешно развернут и базово настроен ==="
echo "Адрес: http://127.0.0.1:8200"
echo "Root token: root"
