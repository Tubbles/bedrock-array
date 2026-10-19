#!/usr/bin/env python3
"""Generate a machine's untextured, segmented model through Tripo (doc/workflows/models.md).

    tools/models/generate.py <id> [--seed 7] [--face-limit <n>] [--smart-low-poly] [--dry-run]

Uploads the four kept views data/art/<id>/turnaround/{front,left,back,right}.png, sends them to Tripo's
multiview to model endpoint, polls the task and downloads the GLB to work/models/<id>/<stem>.glb, with
<stem>.txt beside it recording the task id, the seed, the model version, the face limit, the low poly flag,
the views, the credits spent and the date. The stem is model_<seed>, plus _faces<n> with --face-limit and
_smart with --smart-low-poly. The key is ~/.config/tripo/key, never printed. --dry-run prints the views,
the request body and the output path and makes no request.
"""
import argparse
import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE_URL = "https://openapi.tripo3d.ai"
KEY_PATH = "~/.config/tripo/key"
MODEL_VERSION = "v3.1-20260211"
VIEW_NAMES = ("front", "left", "back", "right")
FINAL_STATUSES = ("success", "failed", "cancelled", "banned", "expired")


def fail(message):
    sys.exit(f"tools/models/generate.py: {message}")


def read_key():
    path = os.path.expanduser(KEY_PATH)
    key = open(path).read().strip() if os.path.isfile(path) else ""
    if not key:
        fail(f"no tripo key: put it in {path}")
    return key


def unwrap(envelope):
    if envelope.get("code") != 0 or envelope.get("status") == "error":
        fail(f"tripo: {envelope.get('message', envelope)}")
    return envelope["data"]


def request(path, key, data=None, content_type=None, method=None):
    headers = {"Authorization": f"Bearer {key}"}
    if content_type:
        headers["Content-Type"] = content_type
    call = urllib.request.Request(BASE_URL + path, data=data, headers=headers, method=method or ("POST" if data else "GET"))
    try:
        with urllib.request.urlopen(call, timeout=300) as response:
            return unwrap(json.loads(response.read()))
    except urllib.error.HTTPError as error:
        fail(f"{path}: HTTP {error.code}: {error.read().decode(errors='replace')[:600]}")
    except urllib.error.URLError as error:
        fail(f"{path}: {error.reason}")


def relative(path):
    return os.path.relpath(path, ROOT)


def views(machine):
    paths = [os.path.join(ROOT, "data", "art", machine, "turnaround", f"{name}.png") for name in VIEW_NAMES]
    missing = [relative(path) for path in paths if not os.path.isfile(path)]
    if missing:
        fail("missing views: " + ", ".join(missing))
    return paths


def multipart_body(path, boundary):
    head = f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{os.path.basename(path)}"\r\nContent-Type: image/png\r\n\r\n'
    return head.encode() + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()


def upload(path, key):
    boundary = uuid.uuid4().hex
    data = request("/v3/files", key, multipart_body(path, boundary), f"multipart/form-data; boundary={boundary}")
    return data["file_token"]


def submit_body(tokens, seed, face_limit, smart_low_poly):
    body = {"inputs": tokens, "model": MODEL_VERSION, "texture": False, "pbr": False, "generate_parts": True, "model_seed": seed}
    if face_limit is not None:
        body["face_limit"] = face_limit
    if smart_low_poly:
        body["smart_low_poly"] = True
    return body


def output_stem(seed, face_limit, smart_low_poly):
    faces = f"_faces{face_limit}" if face_limit is not None else ""
    smart = "_smart" if smart_low_poly else ""
    return f"model_{seed}{faces}{smart}"


def submit(tokens, seed, face_limit, smart_low_poly, key):
    body = json.dumps(submit_body(tokens, seed, face_limit, smart_low_poly)).encode()
    return request("/v3/generation/multiview-to-model", key, body, "application/json")["task_id"]


def wait(task_id, key):
    interval, last = 5, None
    while True:
        task = request(f"/v3/tasks/{task_id}", key)
        state = (task.get("status"), task.get("progress"))
        if state != last:
            print(f"status {state[0]}, progress {state[1]}")
            last = state
        if state[0] in FINAL_STATUSES:
            return task if state[0] == "success" else fail(f"task {task_id}: {json.dumps(task)}")
        time.sleep(interval)
        interval = min(interval * 2, 30)


def model_url(task):
    output = task.get("output") or {}
    url = output.get("model_url") or output.get("model") or output.get("pbr_model")
    return url or fail(f"no model url in task output: {json.dumps(output)}")


def balance(key):
    return request("/v3/account/balance", key)["balance"]


def download(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as response:
        open(path, "wb").write(response.read())


def sidecar_text(task_id, seed, face_limit, smart_low_poly, paths, spent):
    face_limit_text = "none" if face_limit is None else face_limit
    lines = [f"task_id: {task_id}", f"seed: {seed}", f"model: {MODEL_VERSION}", f"face_limit: {face_limit_text}",
             f"smart_low_poly: {'true' if smart_low_poly else 'false'}", f"views: {', '.join(map(relative, paths))}",
             f"credits: {spent}", f"date: {datetime.date.today().isoformat()}"]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("id")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--face-limit", type=int, default=None)
    parser.add_argument("--smart-low-poly", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    arguments = parser.parse_args()
    paths = views(arguments.id)
    stem = output_stem(arguments.seed, arguments.face_limit, arguments.smart_low_poly)
    output = os.path.join(ROOT, "work", "models", arguments.id, f"{stem}.glb")
    if arguments.dry_run:
        body = submit_body(["<file_token>"] * len(paths), arguments.seed, arguments.face_limit, arguments.smart_low_poly)
        print("\n".join(map(relative, paths)), json.dumps(body, indent=2), relative(output), sep="\n")
        return
    key = read_key()
    before = balance(key)
    tokens = [upload(path, key) for path in paths]
    task_id = submit(tokens, arguments.seed, arguments.face_limit, arguments.smart_low_poly, key)
    print(f"task {task_id}")
    download(model_url(wait(task_id, key)), output)
    spent = before - balance(key)
    open(output[:-len(".glb")] + ".txt", "w").write(sidecar_text(task_id, arguments.seed, arguments.face_limit, arguments.smart_low_poly, paths, spent))
    print(f"{relative(output)}, {spent} credits")


if __name__ == "__main__":
    main()
