
# P5-locust/locustfile.py  – versión depurada
import os, random, string, json, time
from locust import HttpUser, task, between, SequentialTaskSet

LOGIN_RETRIES = 2           # Intentos máx. de login antes de rendirse
NONCE_RETRIES = 2           # Reintentos al pedir el nonce

WP_USER     = os.getenv("WP_USER", "florin")
WP_PASSWORD = os.getenv("WP_PASSWORD", "SWAP1234")

def rand_title(prefix="Post"):
    return f"{prefix}-" + "".join(random.choices(string.ascii_letters, k=6))

class CMSFlows(SequentialTaskSet):
    """
    1) Accede a la home (anónimo)
    2) Login clásico (sessi­ón PHP)
    3) Obtiene y cachea un nonce REST
    4) Publica un post y un comentario
    5) Ejecuta búsquedas aleatorias
    """
    nonce          = None      # se comparte entre tasks del mismo usuario
    nonce_refresh  = 0         # timestamp en que hay que renovarlo

    # ---------- Helpers --------------------------------------------------

    def _need_nonce(self):
        """¿El nonce caducó (>12 h) o nunca se pidió?"""
        return self.nonce is None or time.time() > self.nonce_refresh

   
    def _login(self) -> bool:
        """Hace el login clásico con reintento y valida cookie + redirección."""
        payload = {
            "log": WP_USER, "pwd": WP_PASSWORD,
            "wp-submit": "Log In",
            "redirect_to": "/wp-admin/", "testcookie": "1",
        }
        for _ in range(LOGIN_RETRIES):
            with self.client.post("/wp-login.php", data=payload,
                                  name="Login", catch_response=True,
                                  allow_redirects=False) as r:
                if r.status_code in (301, 302) or "Dashboard" in r.text:
                    r.success()
                    return True
                r.failure("login-failed")
                time.sleep(0.3)
        return False                     # agotados intentos

    def _get_nonce(self) -> bool:
        for _ in range(NONCE_RETRIES):
            with self.client.get("/wp-admin/admin-ajax.php?action=rest-nonce",
                             name="Get Nonce", catch_response=True) as r:
             good_json = (
                r.status_code == 200
                and r.headers.get("content-type","").startswith("application/json")
             )
            if good_json:
                try:
                    self.nonce = r.json()["nonce"]
                    self.nonce_refresh = time.time() + 60*60*10
                    r.success();  return True
                except Exception:
                    r.failure("nonce-json")
            elif r.status_code == 200:
                # espera 100 ms y reintenta una vez
                r.failure("nonce-200-wait")
                time.sleep(0.1)
            else:
                r.failure(f"nonce-{r.status_code}")
                time.sleep(0.3)
        return False

    def _with_retry(self, req_fun, *a, **kw):
        """
        Ejecuta la request; si recibe 401/403 intenta renovar nonce y repite
        una única vez. Devuelve la response final (con catch_response).
        """
        with req_fun(*a, **kw, catch_response=True) as r:
            if r.status_code in (401, 403):
                if self._get_nonce():
                    kw["headers"]["X-WP-Nonce"] = self.nonce
                    with req_fun(*a, **kw, catch_response=True) as r2:
                        return r2
            return r

    # ---------- Flujo ----------------------------------------------------

    def on_start(self):
        self.client.get("/", name="Home (anon)")
        time.sleep(random.uniform(0, 1.5))   # ► reduce login storms
        if not self._login():
            return
        self._get_nonce()

    @task
    def create_post(self):
        if self._need_nonce() and not self._get_nonce():
            return

        headers = {"X-WP-Nonce": self.nonce,
                   "Content-Type": "application/json"}
        data = {
            "title":  rand_title(),
            "content": "Contenido generado por Locust 😊",
            "status": "publish"
        }
        r = self._with_retry(self.client.post,
                             "/wp-json/wp/v2/posts",
                             headers=headers,
                             data=json.dumps(data),
                             name="Create Post")
        if r.status_code in (200, 201):
            r.success()
        else:
            r.failure(f"post-{r.status_code}")
    @task
    def add_comment(self):
        if random.random() < 0.4:     # sólo el 40 % de los ciclos comenta
            return                    # (sigue haciendo búsquedas)

        latest_id = self.client.get(
        "/wp-json/wp/v2/posts?per_page=1",
        name="Last Post").json()[0]["id"]
        latest_id = self.client.get(
            "/wp-json/wp/v2/posts?per_page=1",
            name="Last Post").json()[0]["id"]

        headers = {"X-WP-Nonce": self.nonce,
                   "Content-Type": "application/json"}
        data = {
            "post": latest_id,
            "author_name": "LocustBot",
            "author_email": "locust@example.com",
            "content": "Comentario automático"
        }
        r = self._with_retry(self.client.post,
                             "/wp-json/wp/v2/comments",
                             data=json.dumps(data),
                             headers=headers,
                             name="Add Comment")
        if r.status_code in (200, 201):
            r.success()
        else:
            r.failure(f"comment-{r.status_code}")

    @task
    def search(self):
        q = random.choice(["Locust", "SWAP", "flotodor"])
        self.client.get(f"/?s={q}", name="Search")

class P5UsuariosCMS(HttpUser):
    host      = "https://192.168.10.50"  # HAProxy TLS
    tasks     = [CMSFlows]
    wait_time = between(1, 3)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.client.verify = False        # certificado autofirmado