FROM python:3.11-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y build-essential libpq-dev

WORKDIR /app

# Копируем зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем проект
COPY . .

# Сборка статики
RUN python manage.py collectstatic --noinput

# Запуск через gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "django_app.wsgi:application"]

EXPOSE 8000
