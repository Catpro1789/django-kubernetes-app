#!/bin/bash
set -e

NAMESPACE="django"

echo "Создаём namespace..."
kubectl apply -f k8s-manifests/namespace.yaml

echo "Создаём секреты из Vault..."
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

echo "Проверка статуса pod'ов..."
kubectl get pods,svc,ingress -n $NAMESPACE

echo "Деплой завершён."
