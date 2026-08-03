"""Seed dev data into the flightlogs backend via its REST API."""

import base64
import json
import os
import urllib.request
from uuid import uuid4

BASE = "http://localhost:" + os.environ.get("BACKEND_PORT", "8210")
AUTH = "Basic " + base64.b64encode(b"admin:x").decode()

# 1x1 transparent PNG
PNG = base64.b64encode(
    base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNg"
        "YAAAAAMAASsJTYQAAAAASUVORK5CYII="
    )
).decode()


def post(path, payload):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "Authorization": AUTH},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            print("OK ", path, resp.status)
            return json.loads(resp.read() or b"null")
    except urllib.error.HTTPError as e:
        print("ERR", path, e.code, e.read().decode()[:200])
        return None


sim_a = str(uuid4())
sim_b = str(uuid4())
for sid, name, tail in [
    (sim_a, "A320 FFS", "SIM-A320"),
    (sim_b, "B737 FFS", "SIM-B737"),
]:
    post(
        "/simulator",
        {
            "id": sid,
            "name": name,
            "image": PNG,
            "image_type": "image/png",
            "maintenance_window": {"start": "22:00+0000", "end": "06:00+0000"},
            "simulator_id": tail,
            "version": 1,
        },
    )

customers = [
    ("Aer Arann Express", "#1565C0"),
    ("Borealis Air", "#2E7D32"),
    ("Cirrus Charter", "#E65100"),
    ("Dockyard Aviation", "#6A1B9A"),
]
cust_ids = []
for name, color in customers:
    cid = str(uuid4())
    cust_ids.append(cid)
    post(
        "/customer",
        {
            "id": cid,
            "name": name,
            "color": color,
            "image": PNG,
            "image_type": "image/png",
            "version": 1,
        },
    )

instructors = [("Pat Morgan", "#00838F"), ("Alex Reyes", "#AD1457")]
instr = []
for name, color in instructors:
    iid = str(uuid4())
    obj = {"id": iid, "name": name, "color": color, "version": 1}
    instr.append(obj)
    post("/instructor", obj)

# Bookings: week of Mon 2026-07-27 .. Sun 2026-08-02 plus a few in the
# following week. Slots avoid the 22:00-06:00 maintenance window.
slots = [
    # (day, start-hour, end-hour, simulator, customer-idx, label,
    #  instructor-idx or None)
    ("2026-07-27", 8, 12, sim_a, 0, "Type rating LPC", 0),
    ("2026-07-27", 13, 17, sim_a, 1, "OPC renewal", 1),
    ("2026-07-27", 9, 13, sim_b, 2, "Line training", None),
    ("2026-07-28", 6, 10, sim_a, 2, "LOFT session", 1),
    ("2026-07-28", 10, 14, sim_a, 3, "Recurrent day 1", 0),
    ("2026-07-28", 14, 18, sim_b, 0, "Upset recovery", None),
    ("2026-07-29", 8, 12, sim_a, 1, "Recurrent day 2", 1),
    ("2026-07-29", 12, 16, sim_b, 3, "Skill test", 0),
    ("2026-07-30", 7, 11, sim_a, 0, "CAT II/III cert", None),
    ("2026-07-30", 16, 20, sim_a, 2, "Night ops", 0),
    ("2026-07-31", 8, 12, sim_b, 1, "Base check", 1),
    ("2026-07-31", 13, 17, sim_a, 3, "Command upgrade", 0),
    ("2026-08-01", 9, 13, sim_a, 0, "Weekend refresher", 1),
    ("2026-08-01", 14, 18, sim_b, 2, "Ferry crew prep", None),
    ("2026-08-03", 8, 12, sim_a, 1, "Recurrent day 1", 0),
    ("2026-08-04", 8, 12, sim_a, 2, "Recurrent day 2", 1),
]
for day, h1, h2, sim, ci, label, ii in slots:
    time_slot = {
        "from": f"{day}T{h1:02d}:00:00+00:00",
        "to": f"{day}T{h2:02d}:00:00+00:00",
    }
    tech_log = {
        "id": str(uuid4()),
        "assigned_technician": "",
        "ffs": False,
        "configuration": False,
        "time_slot": time_slot,
        "version": 0,
    }
    if ii is not None:
        tech_log["assigned_instructor"] = instr[ii]
    post(
        "/booking",
        {
            "id": str(uuid4()),
            "simulator_id": sim,
            "customer_id": cust_ids[ci],
            "label": label,
            "time_slot": time_slot,
            "tech_log": tech_log,
            "version": 1,
        },
    )
