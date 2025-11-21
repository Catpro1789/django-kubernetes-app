#!/bin/bash
set -e

# -------------------------
# 1. Запуск Vault
# -------------------------
echo "Запускаем Vault..."
cd vault
docker-compose up -d
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

# Проверяем, создан ли секрет в Vault, если нет — создаём
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

# Проверяем группы пользователя
if ! groups $USER | grep -q "\bmicrok8s\b"; then
    echo "Добавляем пользователя в группу microk8s..."
    sudo usermod -a -G microk8s $USER
    echo "Перезапустите терминал или выполните 'newgrp microk8s', затем повторно запустите скрипт"
    exit 0
fi

# Включаем нужные аддоны
echo "Включаем DNS, storage и ingress..."
microk8s enable dns storage ingress
sudo snap alias microk8s.kubectl kubectl
microk8s status --wait-ready

# -------------------------
# 3. Деплой Kubernetes
# -------------------------
NAMESPACE="django"
echo "Создаём namespace..."
kubectl apply -f k8s-manifests/namespace.yaml

echo "Создаём Kubernetes Secret из Vault..."
kubectl create secret generic django-secrets \
  --namespace $NAMESPACE \
  --from-literal=db_user="django_user" \
  --from-literal=db_password="SuperSecret123!" \
  --from-literal=secret_key="django-insecure-your-secret-key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Применяем ConfigMap, Deployment, Service и Ingress..."
kubectl apply -f k8s-manifests/ -n $NAMESPACE

echo "Ждём, пока Django Deployment поднимется..."
kubectl rollout status deployment/django-deployment -n $NAMESPACE --timeout=300s

echo "Проверяем pod'ы и сервисы:"
kubectl get pods,svc,ingress -n $NAMESPACE

# -------------------------
# 4. Проверка балансировки нагрузки
# -------------------------
echo "Запускаем порт-форвардинг Django на localhost:8080..."
kubectl port-forward svc/django-service -n $NAMESPACE 8080:80 &
PF_PID=$!
sleep 5

echo "Проверка балансировки нагрузки (вывод hostname подов):"
for i in {1..10}; do
  curl -s http://localhost:8080/ | grep "Hostname"
done

# Завершаем порт-форвардинг
kill $PF_PID
echo "Порт-форвардинг остановлен."
echo "Готово! Приложение доступно на http://localhost:8080"
