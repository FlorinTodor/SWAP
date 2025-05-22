# P5-locust/locustfile.py
from locust import HttpUser, task, between


# ---- OPCIÓN  A :  solo HTTPS (lo más rápido) ------------------
class P5UsuariosHTTPS(HttpUser):
    """
    Simula usuarios que pasan por el balanceador HTTPS
    (-H https://192.168.10.50:443   en docker-compose).
    """
    wait_time = between(1, 5)

    @task
    def index(self):
        #     OJO ➜   URL RELATIVA,  ¡nunca http://… aquí!
        self.client.get("/index.php", verify=False, name="/index.php")


# ---- OPCIÓN  B :  medir HTTP y HTTPS en paralelo --------------
# (Descomenta si lo necesitas.  Cada clase aparece como “User type”
#  en la GUI y puedes asignarles usuarios por separado).

# class P5UsuariosHTTP(HttpUser):
#     host = "http://192.168.10.50"
#     wait_time = between(1, 5)
#
#     @task
#     def index(self):
#         self.client.get("/index.php", name="/index.php (HTTP)")
#
#
# class P5UsuariosHTTPS(HttpUser):
#     host = "https://192.168.10.50"
#     wait_time = between(1, 5)
#
#     @task
#     def index(self):
#         self.client.get("/index.php", verify=False,
#                        name="/index.php (HTTPS)")
