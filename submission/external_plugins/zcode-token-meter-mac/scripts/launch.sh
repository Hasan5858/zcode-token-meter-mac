#!/bin/bash
# Build (if needed) and launch the TokenMeter widget. No-op if already running.
#
# Notes:
# - Called via `/bin/bash launch.sh` — never rely on the executable bit:
#   ZCode's plugin installer strips exec permissions from installed files.
# - All slow/fallible work (first build, launch) happens in a detached
#   python child (start_new_session) so the SessionStart hook returns
#   instantly and ZCode's hook process-group cleanup can't kill anything.
# - Build failures are surfaced: a macOS notification is shown and details
#   are written to ~/.zcode/token-meter/build-error.log (hook stderr is
#   devnulled, so without this a missing Xcode CLT would fail invisibly).
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

# Self-heal permissions stripped by the plugin installer (best-effort).
chmod +x "$DIR"/*.sh "$DIR/token-meter" 2>/dev/null || true

pgrep -x token-meter >/dev/null 2>&1 && exit 0

if [ ! -x "$DIR/token-meter" ] || [ "$DIR/TokenMeter.swift" -nt "$DIR/token-meter" ]; then
  # Build + launch in a detached, supervised child.
  TOKENMETER_DIR="$DIR" python3 <<'PY' &
import os, pathlib, shutil, subprocess

d = pathlib.Path(os.environ["TOKENMETER_DIR"])
logdir = pathlib.Path.home() / ".zcode" / "token-meter"
logdir.mkdir(parents=True, exist_ok=True)
logfile = logdir / "build-error.log"

def notify(msg: str):
    try:
        subprocess.run(
            ["osascript", "-e",
             f'display notification "{msg}" with title "TokenMeter build failed" sound name "Basso"'],
            timeout=10, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

swiftc = shutil.which("swiftc")
if not swiftc:
    logfile.write_text(
        f"build failed: swiftc not found on PATH.\n"
        "Fix: open Terminal and run  xcode-select --install  , click Install,\n"
        "wait for it to finish, then restart ZCode.\n")
    notify("swiftc not found. Run in Terminal: xcode-select --install — then restart ZCode.")
    raise SystemExit(1)

try:
    r = subprocess.run(["bash", str(d / "build.sh")], cwd=d,
                       capture_output=True, text=True, timeout=300)
except subprocess.TimeoutExpired:
    logfile.write_text("build timed out after 300s (compiler hung — possibly a "
                       "SoftwareUpdate prompt waiting on screen?).\n")
    notify("build timed out. Restart ZCode to retry, or check for a pending installer dialog.")
    raise SystemExit(1)

if r.returncode != 0:
    logfile.write_text(
        f"build failed (exit {r.returncode}).\n--- stdout ---\n{r.stdout}\n"
        f"--- stderr ---\n{r.stderr}\nIf this mentions missing SDK/tools, run: xcode-select --install\n")
    notify("build failed. See ~/.zcode/token-meter/build-error.log (often: xcode-select --install)")
    raise SystemExit(1)

logfile.unlink(missing_ok=True)
subprocess.Popen([str(d / "token-meter")], cwd=d,
                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                 start_new_session=True)
PY
else
  python3 -c "import subprocess; subprocess.Popen(['$DIR/token-meter'], cwd='$DIR', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)"
fi
exit 0
