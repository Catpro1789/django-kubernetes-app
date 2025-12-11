from django.contrib import admin
from django.urls import path
from django.http import HttpResponse
from .settings import get_hostname

def index(request):
    return HttpResponse(f"Hello from pod: {get_hostname()}")

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', index),
    path('health/', lambda request: HttpResponse("OK")),
    path('metrics/', lambda request: HttpResponse("Prometheus metrics")),
]
