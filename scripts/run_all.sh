#!/bin/bash
set -e

NAMESPACE="django"
DJANGO_IMAGE="django-kubernetes-app:latest"
POSTGRES_SECRET_NAME="django-secrets"

# -------------------------
# 1. Запуск Vault
# -------------------------
echo "Запускаем Vault..."
cd vault
docker-compose up -d
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

# Проверяем секреты
if ! vault kv get secret/django-app/database &> /dev/null; then
  echo "Создаём секреты для Django в Vault..."
  vault kv put secret/django-app/database \
    db_name="django_prod" \
    db_user="django_user" \
    db_password="SuperSecret123!" \
    secret_key="django-insecure-your-secret-key"
else
  echo "Секреты для Django уже существуют в Vault."
fi
cd ..

# -------------------------
# 2. Проверка и установка microk8s
# -------------------------
if ! command -v microk8s &> /dev/null; then
    echo "Устанавливаем microk8s..."
    sudo snap install microk8s --classic
else
    echo "microk8s уже установлен"
fi

# Проверяем группу пользователя
if ! groups $USER | grep -q "\bmicrok8s\b"; then
    echo "Добавляем пользователя в группу microk8s..."
    sudo usermod -a -G microk8s $USER
    echo "Перезапустите терминал или выполните 'newgrp microk8s', затем повторно запустите скрипт"
    exit 0
fi

# Включаем нужные аддоны
echo "Включаем DNS, storage и ingress..."
microk8s enable dns
microk8s enable storage
microk8s enable ingress

# Создаём алиас kubectl
sudo snap alias microk8s.kubectl kubectl

# Ждём готовности microk8s
microk8s status --wait-ready

# -------------------------
# 3. Сборка и импорт локального образа Django
# -------------------------
echo "Собираем Docker-образ Django..."
docker build -t $DJANGO_IMAGE .

echo "Импортируем образ в microk8s..."
microk8s ctr image import $DJANGO_IMAGE

# -------------------------
# 4. Деплой Kubernetes
# -------------------------
echo "Создаём namespace..."
kubectl apply -f k8s-manifests/namespace.yaml

echo "Создаём Kubernetes Secret из Vault..."
kubectl create secret generic $POSTGRES_SECRET_NAME \
  --namespace $NAMESPACE \
  --from-literal=db_user="django_user" \
  --from-literal=db_password="SuperSecret123!" \
  --from-literal=secret_key="django-insecure-your-secret-key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Применяем ConfigMap, Deployment, Service, Ingress и Postgres..."
kubectl apply -f k8s-manifests/postgres/ -n $NAMESPACE
kubectl apply -f k8s-manifests/ -n $NAMESPACE

echo "Обновляем Deployment с локальным образом Django..."
kubectl set image deployment/django-deployment django-app=$DJANGO_IMAGE -n $NAMESPACE

echo "Ждём, пока Deployment поднимется..."
kubectl rollout status deployment/django-deployment -n $NAMESPACE --timeout=300s
kubectl rollout status deployment/postgres-deployment -n $NAMESPACE --timeout=300s

echo "Проверяем pod'ы и сервисы:"
kubectl get pods,svc,ingress -n $NAMESPACE

# -------------------------
# 5. Проверка балансировки нагрузки
# -------------------------
echo "Запускаем порт-форвардинг Django на localhost:8080..."
kubectl port-forward svc/django-service -n $NAMESPACE 8080:80 &
PF_PID=$!
sleep 5

echo "Проверка балансировки нагрузки (вывод hostname подов):"
for i in {1..10}; do
  curl -s http://localhost:8080/ | grep "Hostname"
done

kill $PF_PID
echo "Порт-форвардинг остановлен."
echo "Готово! Приложение доступно на http://localhost:8080"
