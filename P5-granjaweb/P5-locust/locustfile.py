# P5-locust/locustfile.py – navegación anónima + login admin + login repetido
import os, random, time
from locust import HttpUser, task, between, SequentialTaskSet

WP_USER     = os.getenv("WP_USER", "florin")
WP_PASSWORD = os.getenv("WP_PASSWORD", "SWAP1234")

# ---------- FLUJO A: navegación anónima ---------------------------------

class PublicBrowsing(SequentialTaskSet):
    @task(3)
    def home(self):
        self.client.get("/", name="Anon - Home")

    @task(2)
    def post_detail(self):
        post_id = random.randint(1, 20)
        self.client.get(f"/?p={post_id}", name="Anon - Post")

    @task(2)
    def search(self):
        q = random.choice(["locust", "wordpress", "swap", "flotodor"])
        self.client.get(f"/?s={q}", name="Anon - Search")

# ---------- FLUJO B: login y navegación por wp-admin ---------------------

class AdminNavigation(SequentialTaskSet):
    def on_start(self):
        """Login al iniciar el usuario."""
        payload = {
            "log": WP_USER,
            "pwd": WP_PASSWORD,
            "wp-submit": "Log In",
            "redirect_to": "/wp-admin/",
            "testcookie": "1"
        }
        with self.client.post("/wp-login.php", data=payload, name="Login", catch_response=True, allow_redirects=False) as r:
            if r.status_code in (301, 302) or "Dashboard" in r.text:
                r.success()
            else:
                r.failure("login-failed")

    @task(2)
    def dashboard(self):
        self.client.get("/wp-admin/index.php", name="Admin - Dashboard")

    @task(1)
    def posts_list(self):
        self.client.get("/wp-admin/edit.php", name="Admin - Posts List")

    @task(1)
    def new_post(self):
        self.client.get("/wp-admin/post-new.php", name="Admin - New Post")

    @task(1)
    def profile(self):
        self.client.get("/wp-admin/profile.php", name="Admin - Profile")

# ---------- FLUJO C: login clásico repetido ------------------------------

class LoginStorm(SequentialTaskSet):
    @task
    def login_attempt(self):
        payload = {
            "log": WP_USER,
            "pwd": WP_PASSWORD,
            "wp-submit": "Log In",
            "redirect_to": "/wp-admin/",
            "testcookie": "1"
        }
        with self.client.post("/wp-login.php", data=payload, name="Login", catch_response=True, allow_redirects=False) as r:
            if r.status_code in (301, 302) or "Dashboard" in r.text:
                r.success()
                time.sleep(random.uniform(0.5, 1.5))  # más suave
            else:
                r.failure("login-failed")
        time.sleep(random.uniform(1, 3))

# ---------- USUARIOS LOCUST ---------------------------------------------

class AnonUser(HttpUser):
    tasks = [PublicBrowsing]
    wait_time = between(1, 3)
    host = "https://192.168.10.50"
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.client.verify = False

class LoginUser(HttpUser):
    tasks = [LoginStorm]
    wait_time = between(4, 10)
    host = "https://192.168.10.50"
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.client.verify = False

class AdminUser(HttpUser):
    tasks = [AdminNavigation]
    wait_time = between(3, 6)
    host = "https://192.168.10.50"
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.client.verify = False
