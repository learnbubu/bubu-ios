# -*- coding: utf-8 -*-
"""
Codemagic from the command line: start a workflow, wait for it, show failures, fetch artifacts.

  python tools/cm.py run native-check          start on main, wait, download artifacts
  python tools/cm.py status <build-id>          one-off status
  python tools/cm.py artifacts <build-id>       download and unzip artifacts

The API token is read from the CODEMAGIC_TOKEN user environment variable.
Artifacts land in tools/.builds/<index>/.
"""
import os, sys, time, json, zipfile, io, urllib.request, urllib.error

APP_ID = "6ab8c09cd9eec6db08156d73"          # learnbubu/bubu-ios in Codemagic
API = "https://api.codemagic.io"
HERE = os.path.dirname(os.path.abspath(__file__))


def token():
    t = os.environ.get("CODEMAGIC_TOKEN")
    if not t and os.name == "nt":
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
            t = winreg.QueryValueEx(k, "CODEMAGIC_TOKEN")[0]
    if not t:
        sys.exit("CODEMAGIC_TOKEN is not set")
    return t


def call(method, path, body=None, raw=False):
    req = urllib.request.Request(API + path if path.startswith("/") else path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"x-auth-token": token(), "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    return data if raw else json.loads(data or b"{}")


def status(bid):
    b = call("GET", f"/builds/{bid}")["build"]
    return b


def show(b):
    print(f"build #{b.get('index')} {b['status']}  ({b.get('fileWorkflowId')})")
    for a in b.get("buildActions", []):
        print(f"   {a.get('status', '?'):>9}  {a.get('name')}")


def failed_log(b, lines=60):
    for a in b.get("buildActions", []):
        if a.get("status") == "failed" and a.get("logUrl"):
            try:
                log = call("GET", a["logUrl"], raw=True).decode("utf-8", "replace").splitlines()
            except Exception as e:
                log = [f"(could not fetch log: {e})"]
            errs = [l for l in log if "error:" in l or "FAILED" in l or "fatal" in l.lower()]
            print(f"\n--- failed step: {a.get('name')} ---")
            print("\n".join((errs[:40] or log[-lines:])))


def artifacts(b):
    out = os.path.join(HERE, ".builds", str(b.get("index")))
    os.makedirs(out, exist_ok=True)
    for art in b.get("artefacts", []):
        data = call("GET", art["url"], raw=True)
        if art["name"].endswith(".zip") and not art["name"].startswith("Bubu-Xcode"):
            zipfile.ZipFile(io.BytesIO(data)).extractall(out)
        else:
            open(os.path.join(out, art["name"]), "wb").write(data)
    files = [os.path.relpath(os.path.join(d, f), out) for d, _, fs in os.walk(out) for f in fs]
    print(f"artifacts in {out}: {', '.join(sorted(files))}")
    return out


def run(workflow, branch="main"):
    bid = call("POST", "/builds", {"appId": APP_ID, "workflowId": workflow, "branch": branch})["buildId"]
    print("started", bid)
    last = None
    while True:
        b = status(bid)
        steps = [(a.get("name"), a.get("status")) for a in b.get("buildActions", [])]
        if steps != last:
            cur = [f"{n}: {s}" for n, s in steps if s not in ("success", "skipped", None)]
            print(f"  {b['status']}  " + (" | ".join(cur) if cur else ""))
            last = steps
        if b["status"] in ("finished", "failed", "canceled", "timeout", "skipped"):
            break
        time.sleep(20)
    show(b)
    if b["status"] != "finished":
        failed_log(b)
    if b.get("artefacts"):
        artifacts(b)
    return b


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "run":
        b = run(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "main")
        sys.exit(0 if b["status"] == "finished" else 1)
    elif cmd == "status":
        b = status(sys.argv[2]); show(b); failed_log(b)
    elif cmd == "artifacts":
        artifacts(status(sys.argv[2]))
    else:
        print(__doc__)
