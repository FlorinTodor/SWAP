from locust import HttpUser, TaskSet, task, between

class P5_tuusuariougr(TaskSet):
    """Tareas concretas: peticiones a la página principal (HTTP y HTTPS)."""

    @task
    def load_index_https(self):
        # HTTPS (balanceador: 192.168.10.50:443) – ignorar Cert autofirmado
        self.client.get("/index.php", verify=False)

    @task
    def load_index_http(self):
        # HTTP (bal. reenvía 80) – se usa el mismo host base configurado con -H
        self.client.get("http://192.168.10.50/index.php", name="/index.php")

class P5_usuarios(HttpUser):
    tasks = [P5_tuusuariougr]
    wait_time = between(1, 5)          # espera aleatoria 1-5 s
