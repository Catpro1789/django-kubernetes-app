#!/bin/bash
set -e

echo "=== 1. Проверка и установка Docker ==="
if ! command -v docker &> /dev/null
then
    echo "Docker не найден. Устанавливаем..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
else
    echo "Docker уже установлен"
fi

echo "=== 2. Проверка и установка kubectl ==="
if ! command -v kubectl &> /dev/null
then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
    echo "kubectl уже установлен"
fi

echo "=== 3. Проверка и установка Helm ==="
if ! command -v helm &> /dev/null
then
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
else
    echo "Helm уже установлен"
fi

echo "=== 4. Проверка и установка Minikube ==="
if ! command -v minikube &> /dev/null
then
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
    sudo dpkg -i minikube_latest_amd64.deb
else
    echo "Minikube уже установлен"
fi

echo "=== 5. Запуск Minikube через Docker driver ==="
minikube delete || true
minikube start --driver=docker --cpus=2 --memory=3072

echo "=== 6. Настройка MetalLB ==="
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.17.255.200-172.17.250
EOF
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: advertise-l2
  namespace: metallb-system
spec: {}
EOF

echo "=== 7. Установка nginx ingress ==="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

echo "=== 8. Установка Vault dev-mode ==="
kubectl create namespace vault || true
helm repo add hashicorp https://helm.hashicorp.com
helm repo update
helm install vault hashicorp/vault --namespace vault --set "server.dev.enabled=true" --set "global.tlsDisable=true"

echo "=== 9. Создание namespace django-app ==="
kubectl apply -f k8s-manifests/namespace.yaml

echo "=== 10. Сборка Docker-образа Django внутри Minikube ==="
eval $(minikube -p minikube docker-env)
docker build -t django-kubernetes-app:latest .

echo "=== 11. Создание секретов ==="
kubectl create secret generic django-secrets -n django-app \
  --from-literal=db_user="django_user" \
  --from-literal=db_password="SuperSecret123!" \
  --from-literal=secret_key="django-insecure-key" || true

echo "=== 12. Деплой Postgres и Django ==="
kubectl apply -f k8s-manifests/postgres/pvc.yaml
kubectl apply -f k8s-manifests/postgres/deployment.yaml
kubectl apply -f k8s-manifests/postgres/service.yaml
kubectl apply -f k8s-manifests/configmap.yaml
kubectl apply -f k8s-manifests/secret.yaml
kubectl apply -f k8s-manifests/deployment.yaml
kubectl apply -f k8s-manifests/service.yaml
kubectl apply -f k8s-manifests/ingress.yaml

echo "=== 13. Ожидание запуска подов ==="
kubectl rollout status deployment/django-deployment -n django-app --timeout=300s
kubectl rollout status deployment/postgres-deployment -n django-app --timeout=300s

echo "=== 14. Проверка подов и сервисов ==="
kubectl get pods -n django-app
kubectl get svc -n django-app
kubectl get ingress -n django-app

echo "=== 15. Port-forward для локального теста ==="
kubectl port-forward svc/django-service -n django-app 8080:80 &
echo "Приложение доступно на http://localhost:8080"

echo "=== 16. Завершено ==="
echo "Проверка логов: kubectl logs -f deployment/django-deployment -n django-app"
echo "Масштабирование: kubectl scale deployment django-deployment --replicas=6 -n django-app"
