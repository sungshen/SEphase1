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


# --------------------------------------------------
# Database
# --------------------------------------------------

def create_db_if_missing():
    if not os.path.exists(DB):
        with sqlite3.connect(DB) as c, open(SCHEMA, encoding="utf-8") as f:
            c.executescript(f.read())


def rows(sql, args=()):
    with sqlite3.connect(DB) as c:
        c.row_factory = sqlite3.Row
        return [dict(r) for r in c.execute(sql, args)]


def row(sql, args=()):
    with sqlite3.connect(DB) as c:
        c.row_factory = sqlite3.Row
        result = c.execute(sql, args).fetchone()
        return dict(result) if result else None


# --------------------------------------------------
# Validation
# --------------------------------------------------

def validate_plan(plan):
    required = [
        "task",
        "date",
        "start_time",
        "end_time",
        "priority"
    ]

    for key in required:
        if key not in plan:
            raise ValueError(f"missing field: {key}")

    if not isinstance(plan["task"], str):
        raise TypeError("task must be a string")

    if not isinstance(plan["date"], str):
        raise TypeError("date must be a string")

    if not isinstance(plan["start_time"], int):
        raise TypeError("start_time must be an integer")

    if not isinstance(plan["end_time"], int):
        raise TypeError("end_time must be an integer")

    if not isinstance(plan["priority"], int):
        raise TypeError("priority must be an integer")

    # 00:00 ~ 23:59
    if not 0 <= plan["start_time"] <= 1439:
        raise ValueError("start_time must be between 0 and 1439")

    if not 0 <= plan["end_time"] <= 1439:
        raise ValueError("end_time must be between 0 and 1439")

    # 자정을 넘기는 일정 금지
    if plan["start_time"] >= plan["end_time"]:
        raise ValueError("start_time must be earlier than end_time")


# --------------------------------------------------
# HTTP Handler
# --------------------------------------------------

class Handler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        agent = self.headers.get("User-Agent", "-") if self.headers else "-"
        super().log_message(format + " [%s]", *args, agent)

    # ----------------------------------------------
    # JSON response
    # ----------------------------------------------

    def send_json(self, status, body):
        data = json.dumps(
            body,
            ensure_ascii=False
        ).encode("utf-8")

        self.send_response(status)
        self.send_header(
            "Content-Type",
            "application/json; charset=utf-8"
        )
        self.send_header(
            "Content-Length",
            str(len(data))
        )
        self.end_headers()
        self.wfile.write(data)

    # ----------------------------------------------
    # Read JSON body
    # ----------------------------------------------

    def read_json(self):
        length = int(self.headers.get("Content-Length", 0))

        if length <= 0:
            raise ValueError("request body is empty")

        data = self.rfile.read(length)

        try:
            return json.loads(data)
        except json.JSONDecodeError:
            raise ValueError("invalid JSON")

    # ==================================================
    # GET
    # ==================================================

    def do_GET(self):

        url = urlparse(self.path)

        if not url.path.startswith("/plans"):
            return self.send_json(
                404,
                {"error": "not found"}
            )

        # ------------------------------------------
        # GET /plans/{id}
        # ------------------------------------------

        if url.path != "/plans":

            plan_id = url.path[len("/plans/"):]

            if not plan_id:
                return self.send_json(
                    404,
                    {"error": "not found"}
                )

            plan = row(
                "SELECT * FROM plans WHERE id = ?",
                (plan_id,)
            )

            if plan is None:
                return self.send_json(
                    404,
                    {"error": "plan not found"}
                )

            return self.send_json(200, plan)

        # ------------------------------------------
        # GET /plans
        # GET /plans?date=2026-10-07
        # ------------------------------------------

        date = parse_qs(url.query).get(
            "date",
            [None]
        )[0]

        if date:
            result = rows(
                """
                SELECT *
                FROM plans
                WHERE date = ?
                ORDER BY start_time ASC
                """,
                (date,)
            )
        else:
            result = rows(
                """
                SELECT *
                FROM plans
                ORDER BY date ASC, start_time ASC
                """
            )

        return self.send_json(200, result)

    # ==================================================
    # POST
    # ==================================================

    def do_POST(self):

        url = urlparse(self.path)

        if url.path != "/plans":
            return self.send_json(
                404,
                {"error": "not found"}
            )

        try:
            plan = self.read_json()

            if not isinstance(plan, dict):
                raise TypeError("request body must be an object")

            validate_plan(plan)

            # Swift에서 id를 보내지 않으면 서버가 생성
            plan["id"] = plan.get("id") or str(
                uuid.uuid4()
            ).upper()

            with sqlite3.connect(DB) as c:

                c.execute(
                    """
                    INSERT INTO plans
                    (
                        id,
                        task,
                        date,
                        start_time,
                        end_time,
                        priority
                    )
                    VALUES
                    (
                        :id,
                        :task,
                        :date,
                        :start_time,
                        :end_time,
                        :priority
                    )
                    """,
                    plan
                )

        except sqlite3.IntegrityError as e:

            return self.send_json(
                409,
                {"error": str(e)}
            )

        except (
            ValueError,
            KeyError,
            TypeError,
            AttributeError,
            sqlite3.Error
        ) as e:

            return self.send_json(
                400,
                {"error": str(e)}
            )

        return self.send_json(
            201,
            plan
        )

    # ==================================================
    # PUT
    # ==================================================

    def do_PUT(self):

        url = urlparse(self.path)

        if not url.path.startswith("/plans/"):
            return self.send_json(
                404,
                {"error": "not found"}
            )

        plan_id = url.path[len("/plans/"):]

        if not plan_id:
            return self.send_json(
                400,
                {"error": "plan id is required"}
            )

        try:
            plan = self.read_json()

            if not isinstance(plan, dict):
                raise TypeError(
                    "request body must be an object"
                )

            validate_plan(plan)

            # URL의 ID를 사용
            plan["id"] = plan_id

            with sqlite3.connect(DB) as c:

                cursor = c.execute(
                    """
                    UPDATE plans
                    SET
                        task = :task,
                        date = :date,
                        start_time = :start_time,
                        end_time = :end_time,
                        priority = :priority
                    WHERE id = :id
                    """,
                    plan
                )

                if cursor.rowcount == 0:
                    return self.send_json(
                        404,
                        {"error": "plan not found"}
                    )

        except (
            ValueError,
            KeyError,
            TypeError,
            AttributeError,
            sqlite3.Error
        ) as e:

            return self.send_json(
                400,
                {"error": str(e)}
            )

        # 수정된 데이터를 다시 반환
        updated = row(
            "SELECT * FROM plans WHERE id = ?",
            (plan_id,)
        )

        return self.send_json(
            200,
            updated
        )

    # ==================================================
    # DELETE
    # ==================================================

    def do_DELETE(self):

        url = urlparse(self.path)

        if not url.path.startswith("/plans/"):
            return self.send_json(
                404,
                {"error": "not found"}
            )

        plan_id = url.path[len("/plans/"):]

        if not plan_id:
            return self.send_json(
                400,
                {"error": "plan id is required"}
            )

        try:

            with sqlite3.connect(DB) as c:

                cursor = c.execute(
                    """
                    DELETE FROM plans
                    WHERE id = ?
                    """,
                    (plan_id,)
                )

                if cursor.rowcount == 0:
                    return self.send_json(
                        404,
                        {"error": "plan not found"}
                    )

        except sqlite3.Error as e:

            return self.send_json(
                400,
                {"error": str(e)}
            )

        return self.send_json(
            200,
            {
                "message": "plan deleted",
                "id": plan_id
            }
        )


# --------------------------------------------------
# Start Server
# --------------------------------------------------

if __name__ == "__main__":

    create_db_if_missing()

    print(
        f"Server running at "
        f"http://localhost:{PORT}/plans "
        f"(Ctrl+C to stop)"
    )

    HTTPServer(
        ("0.0.0.0", PORT),
        Handler
    ).serve_forever()
