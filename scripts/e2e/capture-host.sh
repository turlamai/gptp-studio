#!/usr/bin/env bash
# Screenshot the packaged GTK4 host page by page on a headless X server, in
# both color schemes, for the prototype-vs-build comparison (issue #64).
# Each page is a fresh launch opened through the host's GPTP_DEV_PAGE hook;
# capture-pages.py says why the sidebar is not clicked instead.
# Needs a D-Bus session bus: dbus-run-session -- bash scripts/e2e/capture-host.sh
# Pictures and their manifest land in .rivet/acceptance/linux/captures/.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
output="$repo/.rivet/acceptance/linux/captures"
executable="$(find "$repo/dist" -type f -name gptp-studio -perm -u+x -print -quit)"
[[ -n "$executable" && -x "$executable" ]]
rm -rf "$output"
mkdir -p "$output"

export GPTP_STUDIO_HOME="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/gptp-capture-home-$$"
export GDK_BACKEND=x11
export GTK_A11Y=atspi
export NO_AT_BRIDGE=0
export LANG=C.UTF-8
# The product's default language (zh) keeps the pictures comparable with
# design/prototype/, whose copy is Chinese.
export HOME="$GPTP_STUDIO_HOME"
mkdir -p "$GPTP_STUDIO_HOME"

display=":$((100 + $$ % 100))"
Xvfb "$display" -screen 0 1200x820x24 -nolisten tcp >"$output/xvfb.log" 2>&1 &
xvfb_pid=$!
export DISPLAY="$display"

launcher="$(command -v at-spi-bus-launcher || true)"
[[ -n "$launcher" ]] || launcher=/usr/libexec/at-spi-bus-launcher
"$launcher" --launch-immediately >"$output/at-spi-bus.log" 2>&1 &
atspi_pid=$!

app_pid=""
cleanup() {
  [[ -n "$app_pid" ]] && kill -TERM "$app_pid" 2>/dev/null || true
  kill -TERM "$atspi_pid" "$xvfb_pid" 2>/dev/null || true
  wait "$app_pid" "$atspi_pid" "$xvfb_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 100); do
  xdotool getdisplaygeometry >/dev/null 2>&1 && break
  kill -0 "$xvfb_pid" 2>/dev/null
  sleep 0.05
done
xdotool getdisplaygeometry >/dev/null

for _ in $(seq 1 100); do
  gdbus call --session --dest org.a11y.Bus --object-path /org/a11y/bus \
    --method org.a11y.Bus.GetAddress >/dev/null 2>&1 && break
  kill -0 "$atspi_pid" 2>/dev/null
  sleep 0.05
done
export AT_SPI_BUS_ADDRESS="$(gdbus call --session --dest org.a11y.Bus \
  --object-path /org/a11y/bus --method org.a11y.Bus.GetAddress |
  sed -E "s/^\('([^']+)',\)$/\1/")"

# Stack page name = sidebar label, in navigation order.
pages=(engine 引擎 qualification 资格检测 packets 报文 logs 日志
  tuning "GM 调优" license 工程报告)

status=0
for scheme in light dark; do
  # The host reads the scheme through GTK's dark variant; GTK_THEME pins it
  # so the two runs do not depend on the runner's desktop settings.
  export GTK_THEME="Adwaita:$scheme"
  mkdir -p "$output/$scheme"
  names=()
  i=0
  while [[ $i -lt ${#pages[@]} ]]; do
    name="${pages[$i]}"
    label="${pages[$((i + 1))]}"
    i=$((i + 2))
    GPTP_DEV_PAGE="$name" "$executable" >"$output/$scheme.log" 2>&1 &
    app_pid=$!
    if ! /usr/bin/python3 "$repo/scripts/e2e/capture-pages.py" \
      --output "$output/$scheme" --busy-text "正在启动内嵌" --settle 2 \
      "$name.png"; then
      status=1
    fi
    for _ in $(seq 1 200); do
      kill -0 "$app_pid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$app_pid" 2>/dev/null; then
      echo "$scheme/$name: the host did not exit after the native close" >&2
      status=1
    fi
    app_pid=""
    names+=("$name")
  done
  # Six pictures of one page is not evidence: every page must look different.
  distinct=$(sha256sum "$output/$scheme"/*.png | cut -d' ' -f1 | sort -u | wc -l)
  if [[ "$distinct" -ne ${#names[@]} ]]; then
    echo "$scheme: only $distinct distinct pictures of ${#names[@]} pages" >&2
    status=1
  fi
  printf '{"scheme":"%s","language":"zh","pages":["%s"]}\n' \
    "$scheme" "$(IFS='","'; echo "${names[*]}")" >"$output/$scheme/captures.json"
done
exit "$status"
