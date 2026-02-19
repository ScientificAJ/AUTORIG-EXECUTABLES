#!/usr/bin/env bash
set -Eeuo pipefail

# AutoRig Distribution Setup Helper
#
# This repository ships prebuilt artifacts (CLI binary + Blender add-on).
# No Python/Node installation is required.
#
# EXPERIMENTAL: pass --geometric to launch the "Draw -> Recognize -> Correct" UI.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLI_BIN=""

HOST="${AUTORIG_API_HOST:-127.0.0.1}"
PORT="${AUTORIG_API_PORT:-8000}"
WAIT_SECONDS="${AUTORIG_SETUP_WAIT_SECONDS:-30}"
GEOMETRIC=0
NO_OPEN=0
FOUND_EXISTING=0
SERVER_PID=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --host <host>          Bind host for local API server (default: ${HOST}).
  --port <port>          Preferred port for local API server (default: ${PORT}).
  --wait-seconds <n>     Health-check timeout for startup (default: ${WAIT_SECONDS}).
  --geometric            Launch EXPERIMENTAL geometric inference drawing UI.
  --no-open              Do not auto-open the browser window.
  -h, --help             Show this help.

Examples:
  # Run API server (Swagger docs at /docs)
  bash ./bin/setup.sh --host 127.0.0.1 --port 8000

  # EXPERIMENTAL: open the drawing window and run geometric inference rigs
  bash ./bin/setup.sh --geometric
USAGE
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

is_port_in_use() {
  local port="$1"

  if command_exists ss; then
    if ss -H -ltn 2>/dev/null | awk -v needle=":${port}" '$4 ~ needle"$" {found=1} END {exit(found ? 0 : 1)}'; then
      return 0
    fi
  fi

  if command_exists lsof; then
    if lsof -iTCP:"${port}" -sTCP:LISTEN -t >/dev/null 2>&1; then
      return 0
    fi
  fi

  return 1
}

port_owner() {
  local port="$1"
  if ! command_exists lsof; then
    return 0
  fi
  lsof -iTCP:"${port}" -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR==2 {print $1 " (PID " $2 ")"}' || true
}

format_host_for_url() {
  local host="$1"
  if [[ "$host" == "0.0.0.0" || "$host" == "::" ]]; then
    host="127.0.0.1"
  fi
  if [[ "$host" == *:* && "$host" != \[* ]]; then
    host="[${host}]"
  fi
  printf '%s' "$host"
}

health_url() {
  local host="$1"
  local port="$2"
  printf 'http://%s:%s/healthz' "$(format_host_for_url "$host")" "$port"
}

docs_url() {
  local host="$1"
  local port="$2"
  printf 'http://%s:%s/docs' "$(format_host_for_url "$host")" "$port"
}

geometric_url() {
  local host="$1"
  local port="$2"
  printf 'http://%s:%s/experimental/geometric' "$(format_host_for_url "$host")" "$port"
}

is_http_healthy() {
  local host="$1"
  local port="$2"
  local url
  url="$(health_url "$host" "$port")"
  curl -fsS --max-time 2 "$url" >/dev/null 2>&1
}

open_browser() {
  local url="$1"
  if [[ "$NO_OPEN" -eq 1 ]]; then
    return 0
  fi

  if command_exists xdg-open; then
    xdg-open "$url" >/dev/null 2>&1 || true
    return 0
  fi

  if command_exists open; then
    open "$url" >/dev/null 2>&1 || true
    return 0
  fi
}

resolve_port() {
  local host="$1"
  local requested="$2"
  local service_name="$3"
  local chosen="$requested"

  FOUND_EXISTING=0

  while true; do
    if is_http_healthy "$host" "$chosen"; then
      FOUND_EXISTING=1
      printf '%s' "$chosen"
      return 0
    fi

    if is_port_in_use "$chosen"; then
      local owner
      owner="$(port_owner "$chosen")"
      echo "[WARN] ${service_name} port ${chosen} is in use${owner:+ by ${owner}}." >&2
      chosen=$((chosen + 1))
      continue
    fi

    printf '%s' "$chosen"
    return 0
  done
}

wait_for_health() {
  local host="$1"
  local port="$2"
  local timeout="$3"
  local elapsed=0

  while (( elapsed < timeout )); do
    if is_http_healthy "$host" "$port"; then
      return 0
    fi

    if [[ -n "$SERVER_PID" ]] && ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
      return 1
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --host)
        HOST="${2:-}"
        [[ -n "$HOST" ]] || { echo "Missing value for --host" >&2; exit 2; }
        shift
        ;;
      --port)
        PORT="${2:-}"
        [[ "$PORT" =~ ^[0-9]+$ ]] || { echo "Invalid port: $PORT" >&2; exit 2; }
        shift
        ;;
      --wait-seconds)
        WAIT_SECONDS="${2:-}"
        [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || { echo "Invalid wait timeout: $WAIT_SECONDS" >&2; exit 2; }
        shift
        ;;
      --geometric)
        GEOMETRIC=1
        ;;
      --no-open)
        NO_OPEN=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 2
        ;;
    esac
    shift
  done
}

print_server_urls() {
  local host="$1"
  local port="$2"
  echo "Open: $(docs_url "$host" "$port")" >&2
  echo "Health: $(health_url "$host" "$port")" >&2
}

run_server_mode() {
  local chosen_port
  chosen_port="$(resolve_port "$HOST" "$PORT" "API")"

  if [[ "$FOUND_EXISTING" -eq 1 ]]; then
    echo "Detected existing healthy AutoRig API on port ${chosen_port}; reusing it." >&2
    print_server_urls "$HOST" "$chosen_port"
    echo "Stop: Ctrl+C (no local server started by this script)" >&2
    return 0
  fi

  if [[ "$chosen_port" != "$PORT" ]]; then
    echo "[WARN] API port ${PORT} unavailable; using fallback port ${chosen_port}." >&2
  fi

  echo "Starting AutoRig API server..." >&2
  print_server_urls "$HOST" "$chosen_port"
  echo "Stop: Ctrl+C" >&2

  "$CLI_BIN" server --host "$HOST" --port "$chosen_port" &
  SERVER_PID=$!

  if ! wait_for_health "$HOST" "$chosen_port" "$WAIT_SECONDS"; then
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
      echo "[WARN] Health endpoint did not respond within ${WAIT_SECONDS}s: $(health_url "$HOST" "$chosen_port")" >&2
      echo "[WARN] Server process is still running on port ${chosen_port}; continuing anyway." >&2
    else
      echo "AutoRig API failed health check within ${WAIT_SECONDS}s: $(health_url "$HOST" "$chosen_port")" >&2
      return 1
    fi
  fi

  wait "$SERVER_PID"
}

run_geometric_mode() {
  local chosen_port
  chosen_port="$(resolve_port "$HOST" "$PORT" "EXPERIMENTAL geometric UI")"

  if [[ "$FOUND_EXISTING" -eq 1 ]]; then
    local ui
    ui="$(geometric_url "$HOST" "$chosen_port")"
    if curl -fsS --max-time 2 "$ui" >/dev/null 2>&1; then
      echo "Detected running AutoRig server on port ${chosen_port}; opening existing geometric UI." >&2
      echo "Open: ${ui}" >&2
      open_browser "$ui"
      return 0
    fi
    echo "[WARN] Existing API on port ${chosen_port} does not expose geometric UI; starting new geometric server." >&2
    PORT="$((chosen_port + 1))"
    chosen_port="$(resolve_port "$HOST" "$PORT" "EXPERIMENTAL geometric UI")"
  fi

  if [[ "$chosen_port" != "$PORT" ]]; then
    echo "[WARN] Geometric UI port ${PORT} unavailable; using fallback port ${chosen_port}." >&2
  fi

  if [[ "$NO_OPEN" -eq 1 ]]; then
    exec "$CLI_BIN" geometric-ui --host "$HOST" --port "$chosen_port" --no-open
  fi
  exec "$CLI_BIN" geometric-ui --host "$HOST" --port "$chosen_port"
}

main() {
  parse_args "$@"

  local candidate
  for candidate in \
    "${ROOT_DIR}/bin/autorig_cli-linux-x86_64" \
    "${ROOT_DIR}/binary/autorig_cli"; do
    if [[ -x "$candidate" ]]; then
      CLI_BIN="$candidate"
      break
    fi
  done

  if [[ -z "$CLI_BIN" ]]; then
    echo "Missing CLI binary. Looked for:" >&2
    echo "  - ${ROOT_DIR}/bin/autorig_cli-linux-x86_64" >&2
    echo "  - ${ROOT_DIR}/binary/autorig_cli" >&2
    exit 2
  fi

  trap cleanup EXIT INT TERM

  if [[ "$GEOMETRIC" -eq 1 ]]; then
    run_geometric_mode
    return
  fi

  run_server_mode
}

main "$@"
