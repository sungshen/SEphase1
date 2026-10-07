import json
import os
import sqlite3
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "plans.db")
SCHEMA = os.path.join(HERE, "plans.sql")
PORT = 8000


def create_db_if_missing():
    if not os.path.exists(DB):
        with sqlite3.connect(DB) as c, open(SCHEMA, encoding="utf-8") as f:
            c.executescript(f.read())


def rows(sql, args=()):
    with sqlite3.connect(DB) as c:
        c.row_factory = sqlite3.Row
        return [dict(r) for r in c.execute(sql, args)]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # also print which program sent the request (the app, Safari, curl...)
        agent = self.headers.get("User-Agent", "-") if self.headers else "-"
        super().log_message(format + " [%s]", *args, agent)

    def send_json(self, status, body):
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path != "/plans":
            return self.send_json(404, {"error": "not found"})
        date = parse_qs(url.query).get("date", [None])[0]
        if date:
            self.send_json(200, rows("SELECT * FROM plans WHERE date = ?", (date,)))
        else:
            self.send_json(200, rows("SELECT * FROM plans"))

    def do_POST(self):
        if self.path != "/plans":
            return self.send_json(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", 0))
            plan = json.loads(self.rfile.read(length))
            plan["id"] = plan.get("id") or str(uuid.uuid4()).upper()
            with sqlite3.connect(DB) as c:
                c.execute(
                    "INSERT INTO plans (id, task, date, start_time, end_time, priority) "
                    "VALUES (:id, :task, :date, :start_time, :end_time, :priority)",
                    plan,
                )
        except (ValueError, KeyError, TypeError, AttributeError, sqlite3.Error) as e:
            return self.send_json(400, {"error": str(e)})
        self.send_json(201, plan)


if __name__ == "__main__":
    create_db_if_missing()
    print(f"Server running at http://localhost:{PORT}/plans (Ctrl+C to stop)")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
