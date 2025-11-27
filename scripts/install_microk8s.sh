#!/usr/bin/env bash
set -e

echo "=== Обновление системы ==="
sudo apt update -y

echo "=== Установка MicroK8s ==="
sudo snap install microk8s --classic --channel=1.30

echo "=== Добавление текущего пользователя в группу microk8s ==="
sudo usermod -aG microk8s $USER
sudo chown -f -R $USER ~/.kube || true

echo "=== Ожидание готовности кластера ==="
sudo microk8s status --wait-ready

echo "=== Включение базовых аддонов ==="
sudo microk8s enable dns
sudo microk8s enable storage
sudo microk8s enable ingress
sudo microk8s enable registry

echo "=== Создание alias kubectl ==="
sudo snap alias microk8s.kubectl kubectl

echo "=== Генерация kubeconfig для kubectl ==="
mkdir -p ~/.kube
sudo microk8s config > ~/.kube/config

echo "=== Проверка узлов ==="
kubectl get nodes -o wide

echo "=== Готово! MicroK8s установлен и настроен. ==="
echo "⚠ Важно: перезайдите в систему, чтобы применились группы:"
echo "    newgrp microk8s"
