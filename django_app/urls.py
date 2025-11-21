from django.urls import path
from django.http import HttpResponse
from .settings import get_hostname

def index(request):
    # Показываем hostname пода
    return HttpResponse(f"Hostname: {get_hostname()}")

urlpatterns = [
    path('', index),
]
