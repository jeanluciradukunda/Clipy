import json, os, re, subprocess, sys, time

APP = sys.argv[1]
BIN = os.path.join(APP, "Contents/MacOS/Clipy")
OUT = {}
SUPPORT = os.path.expanduser("~/Library/Application Support/Clipy")


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()


def cpu_seconds(pid):
    t = sh(f"ps -o time= -p {pid}")
    m = re.match(r"(?:(\d+):)?(\d+):(\d+\.\d+)", t)
    if not m:
        return None
    h = int(m.group(1) or 0)
    return h * 3600 + int(m.group(2)) * 60 + float(m.group(3))


def memory(pid):
    fp = sh(f"sudo footprint -p {pid} 2>/dev/null | grep -i 'phys_footprint:'")
    m = re.search(r"([\d.]+)\s*([KMG]B)", fp)
    footprint = None
    if m:
        footprint = float(m.group(1)) * {"KB": 1 / 1024, "MB": 1, "GB": 1024}[m.group(2)]
    rss = int(sh(f"ps -o rss= -p {pid}") or 0) / 1024
    return {"footprint_mb": footprint, "rss_mb": round(rss, 1)}


def launch(label):
    stream = subprocess.Popen(
        ["log", "stream", "--level", "info", "--style", "ndjson",
         "--predicate", 'subsystem == "com.clipy-app.Clipy" AND eventMessage CONTAINS "launched successfully"'],
        stdout=subprocess.PIPE, text=True)
    time.sleep(2)
    t0 = time.time()
    proc = subprocess.Popen([BIN], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    launched = None
    deadline = t0 + 60
    while time.time() < deadline:
        line = stream.stdout.readline()
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if "launched successfully" in event.get("eventMessage", ""):
            launched = time.time()
            break
    stream.terminate()
    OUT[f"{label}_launch_s"] = round(launched - t0, 3) if launched else None
    time.sleep(10)
    OUT[f"{label}_mem_after_10s"] = memory(proc.pid)
    c0 = cpu_seconds(proc.pid)
    time.sleep(30)
    c1 = cpu_seconds(proc.pid)
    OUT[f"{label}_idle_cpu_pct_30s"] = round((c1 - c0) / 30 * 100, 2) if c0 is not None and c1 is not None else None
    return proc


def copy_text(i):
    text = f"perf probe clip {i} " + ("lorem ipsum dolor sit amet " * 8)
    subprocess.run(["pbcopy"], input=text, text=True)


def copy_image(i, base):
    path = f"/tmp/probe-{i}.png"
    sh(f"sips -z {64 + i} {64 + i} '{base}' --out '{path}' >/dev/null 2>&1")
    sh(f"osascript -e 'set the clipboard to (read (POSIX file \"{path}\") as «class PNGf»)'")


def seed(proc, start, end, base):
    c0 = cpu_seconds(proc.pid)
    t0 = time.time()
    for i in range(start, end):
        if i % 20 == 19:
            copy_image(i, base)
        else:
            copy_text(i)
        time.sleep(0.6)
    time.sleep(2)
    c1 = cpu_seconds(proc.pid)
    n = end - start
    return {"clips": n, "cpu_ms_per_capture": round((c1 - c0) / n * 1000, 2), "wall_s": round(time.time() - t0, 1)}


def try_search_panel(proc):
    c0 = cpu_seconds(proc.pid)
    r = subprocess.run(["osascript", "-e", 'tell application "System Events" to keystroke "v" using {command down, shift down}'],
                       capture_output=True, text=True)
    time.sleep(3)
    c1 = cpu_seconds(proc.pid)
    return {"osascript_ok": r.returncode == 0, "stderr": r.stderr.strip()[:200],
            "cpu_ms_3s_after_hotkey": round((c1 - c0) * 1000, 1), "mem": memory(proc.pid)}


base = "/tmp/probe-base.png"
sh(f"sips -s format png '{APP}/Contents/Resources/AppIcon.icns' --out {base}")

proc = launch("empty")
OUT["empty_search_panel"] = try_search_panel(proc)
sh("osascript -e 'tell application \"System Events\" to key code 53'")
time.sleep(2)
OUT["empty_search_panel_second_open"] = try_search_panel(proc)
sh("osascript -e 'tell application \"System Events\" to key code 53'")
OUT["seed_first_100"] = seed(proc, 0, 100, base)
OUT["seed_middle_800"] = seed(proc, 100, 900, base)
OUT["seed_last_100"] = seed(proc, 900, 1000, base)
OUT["full_mem"] = memory(proc.pid)
c0 = cpu_seconds(proc.pid); time.sleep(30); c1 = cpu_seconds(proc.pid)
OUT["full_idle_cpu_pct_30s"] = round((c1 - c0) / 30 * 100, 2)
OUT["full_search_panel"] = try_search_panel(proc)
proc.terminate(); proc.wait(timeout=20)

realm = sh("find ~/Library/Application\\ Support -name 'default.realm' -newer " + base + " 2>/dev/null")
OUT["realm_files"] = {p: os.path.getsize(p) for p in realm.splitlines() if p}
OUT["support_dir"] = sh(f"du -sk '{SUPPORT}' 2>/dev/null")
OUT["support_files"] = sh(f"ls '{SUPPORT}' 2>/dev/null | wc -l")
OUT["thumbnail_cache"] = sh("du -sk ~/Library/Caches/com.clipy-app.Clipy 2>/dev/null")

proc = launch("full")
OUT["full_relaunch_search_panel"] = try_search_panel(proc)
proc.terminate()

print(json.dumps(OUT, indent=2))
json.dump(OUT, open("perf-results.json", "w"), indent=2)
