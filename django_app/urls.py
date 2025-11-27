from django.http import HttpResponse
from django.urls import path
from django_app.settings import get_hostname

def index(request):
    return HttpResponse(f"Hostname: {get_hostname()}")

urlpatterns = [
    path("", index),
    path("health/", lambda r: HttpResponse("OK")),
]
