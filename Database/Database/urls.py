"""
URL configuration for Database project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path
from .views import *
from django.conf.urls.static import static

urlpatterns = [
    path('api/admin/', admin.site.urls),
    path('api/problems/', GetProblems.as_view()),
    path('api/tags/', GetTags.as_view()),
    path('api/register/', Register.as_view()),
    path('api/login/', Login.as_view()),
    path('api/contests/', GetContests.as_view()),
    path('api/enroll/', EnrollContest.as_view()),
    path('api/problem/<int:problem_id>/', GetProblemSpecific.as_view()),
    path('api/toturial/<int:problem_id>/', GetToturial.as_view()),
    path('api/contest/<int:contest_id>/', GetContestSpecific.as_view()),
    path('api/create-contest/', CreateContest.as_view()),
    path('api/create-delete-problem/', CreateProblem.as_view()),
    path('api/add-admin/', AddAdmin.as_view()),
    path('api/get-admins/<int:contest_id>/', GetAdmins.as_view()),
    path('api/get-scoreboard/<int:contest_id>/', GetScoreBoard.as_view()),
    path('api/get-submissions/', GetSubmissions.as_view()),
    path('api/submit/', SubmitCode.as_view()),



]
