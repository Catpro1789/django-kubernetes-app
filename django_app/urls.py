from django.urls import path
from django.http import HttpResponse
from django_app.settings import get_hostname

def index(request):
    return HttpResponse(f"Hello! Hostname: {get_hostname()}")

urlpatterns = [
    path('', index),
]

