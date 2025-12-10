from django.urls import path
from django.http import HttpResponse
from .settings import get_hostname

def index(request):
    return HttpResponse(f"Hello from pod: {get_hostname()}")

urlpatterns = [
    path('', index),
]
