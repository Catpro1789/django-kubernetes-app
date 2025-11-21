#!/bin/bash
set -e

# 1. Запуск Vault
echo "Запускаем Vault..."
cd vault
docker-compose up -d
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

# Создаём секреты для Django
vault kv put secret/django-app/database \
  db_name="django_prod" \
  db_user="django_user" \
  db_password="SuperSecret123!" \
  secret_key="django-insecure-your-secret-key"

cd ..

# 2. Установка microk8s
echo "Устанавливаем microk8s..."
sudo snap install microk8s --classic || true
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
microk8s enable dns storage ingress
sudo snap alias microk8s.kubectl kubectl
microk8s status --wait-ready

# 3. Деплой Kubernetes
echo "Деплой приложения в Kubernetes..."
NAMESPACE="django"

kubectl apply -f k8s-manifests/namespace.yaml

kubectl create secret generic django-secrets \
  --namespace $NAMESPACE \
  --from-literal=db_user="django_user" \
  --from-literal=db_password="SuperSecret123!" \
  --from-literal=secret_key="django-insecure-your-secret-key" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f k8s-manifests/ -n $NAMESPACE

kubectl rollout status deployment/django-deployment -n $NAMESPACE --timeout=300s

echo "Стек поднят! Проверяем pod'ы и сервисы:"
kubectl get pods,svc,ingress -n $NAMESPACE

# 4. Автоматическая проверка балансировки нагрузки
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
