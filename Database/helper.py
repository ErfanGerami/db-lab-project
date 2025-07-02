from rest_framework.views import APIView
from rest_framework.response import Response
from django.conf import settings
from django.db import connection
from Database.settings import SECRET_KEY, EXPIRATION_TIME
import hashlib
from datetime import datetime, timedelta
import jwt
import hashlib


class Serializer():
    fields = []

    def __init__(self, obj):
        self.__obj = obj
        if type(self.__obj) == list:
            self.__many = True
        else:
            self.__many = False

        if (self.__many):

            self.data = []
            for one in self.__obj:
                self.data.append({})
                for i in self.fields:
                    if (hasattr(self, i)):
                        self.data[-1][i] = eval(
                            f'self.get_{i}(one)')
                    else:
                        self.data[-1][i] = one[i]
        else:
            self.data = {}
            for i in self.fields:
                if (hasattr(self, i)):
                    parameter = self.__obj
                    self.data[i] = eval(f'self.get_{i}(parameter)')
                else:
                    self.data[i] = self.__obj[i]


def select(query, params=None):
    with connection.cursor() as cursor:
        cursor.execute(query, params or [])
        rows = cursor.fetchall()
        columns = [col[0] for col in cursor.description]
        return [dict(zip(columns, row)) for row in rows]


def execute(query: str, params=None, get_result=True, commit=False):
    rows = list()
    desc = list()
    with connection.cursor() as cursor:
        cursor.execute(query, params)
        if (get_result):
            desc = [col[0] for col in cursor.description]

        if (get_result):
            rows = cursor.fetchall()
        if (commit):
            connection.commit()
    if (get_result):
        return [desc, list(rows)]
    else:
        return None


class MyListView(APIView):
    serializer = None
    query_set = None

    def get(self, request):
        objects = None
        if (hasattr(self, 'get_query_set')):
            objects = self.get_query_set(request)
        else:
            objects = select(self.query_set)
        return Response(self.serializer(objects).data)


def generate_jwt_token(username, password,):
    expiration = datetime.utcnow() + EXPIRATION_TIME
    payload = {
        'username': username,
        'exp': expiration,
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')
    return token


def authenticate(token):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])

        row = execute("select * from users where password=%s  and username=%s ",
                      [payload["password"], payload["username"]])[1]
        if (len(row) != 1):
            return None
        return row[0][0]
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def hash_pass(password):
    return hashlib.sha256(password.encode()).hexdigest()
