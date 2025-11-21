#!/bin/bash
set -e

echo "Установка microk8s..."
sudo snap install microk8s --classic

echo "Добавляем пользователя в группу microk8s..."
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube

echo "Включаем необходимые компоненты..."
microk8s enable dns storage ingress

echo "Устанавливаем alias kubectl"
sudo snap alias microk8s.kubectl kubectl

echo "Проверяем состояние кластера..."
microk8s status --wait-ready

echo "Готово! Перезапустите терминал, если нужно."
