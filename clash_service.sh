#!/bin/sh
# clash_service.sh — Manage Clash/Mihomo proxy lifecycle on ASUSWRT-Merlin
# Compatible with busybox ash (POSIX sh)

CLASH_DIR="/jffs/clash"
CLASH_BIN="$CLASH_DIR/clash"
CLASH_CONFIG="$CLASH_DIR/config.yaml"
CLASH_PID_FILE="$CLASH_DIR/clash.pid"
CLASH_LOG="/tmp/clash.log"
CLASH_EXT_CTL="127.0.0.1:9090"

log_msg() {
    logger -t "clash-webui" "$1"
}

get_clash_secret() {
    _secret=""
    if [ -f "$CLASH_CONFIG" ]; then
        _secret=$(grep '^secret:' "$CLASH_CONFIG" | awk '{print $2}')
    fi
    echo "$_secret"
}

is_running() {
    _pid=""
    if [ -f "$CLASH_PID_FILE" ]; then
        _pid=$(cat "$CLASH_PID_FILE" 2>/dev/null)
    fi
    if [ -z "$_pid" ]; then
        return 1
    fi
    if [ -d "/proc/$_pid" ]; then
        return 0
    fi
    rm -f "$CLASH_PID_FILE"
    return 1
}

get_uptime_seconds() {
    _pid=""
    if [ -f "$CLASH_PID_FILE" ]; then
        _pid=$(cat "$CLASH_PID_FILE" 2>/dev/null)
    fi
    if [ -z "$_pid" ] || [ ! -d "/proc/$_pid" ]; then
        echo "0"
        return
    fi
    _sys_uptime=$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null)
    _start_ticks=$(awk '{print $22}' "/proc/$_pid/stat" 2>/dev/null)
    if [ -z "$_start_ticks" ] || [ -z "$_sys_uptime" ]; then
        echo "0"
        return
    fi
    _clk_tck=$(getconf CLK_TCK 2>/dev/null || echo 100)
    _start_secs=$((_start_ticks / _clk_tck))
    _proc_uptime=$((_sys_uptime - _start_secs))
    if [ "$_proc_uptime" -lt 0 ]; then
        _proc_uptime=0
    fi
    echo "$_proc_uptime"
}

format_uptime() {
    _secs=$1
    if [ "$_secs" -lt 60 ]; then
        echo "${_secs}s"
    elif [ "$_secs" -lt 3600 ]; then
        _mins=$((_secs / 60))
        _rem_secs=$((_secs % 60))
        echo "${_mins}m ${_rem_secs}s"
    else
        _hrs=$((_secs / 3600))
        _rem_mins=$(((_secs % 3600) / 60))
        echo "${_hrs}h ${_rem_mins}m"
    fi
}

get_mode() {
    _secret=$(get_clash_secret)
    _auth_header=""
    if [ -n "$_secret" ]; then
        _auth_header="Authorization: Bearer $_secret"
    fi
    _result=""
    if [ -n "$_auth_header" ]; then
        _result=$(curl -s -H "$_auth_header" "http://$CLASH_EXT_CTL/configs" 2>/dev/null)
    else
        _result=$(curl -s "http://$CLASH_EXT_CTL/configs" 2>/dev/null)
    fi
    _mode=$(echo "$_result" | grep -o '"mode":"[^"]*"' | head -1 | sed 's/"mode":"//;s/"//')
    if [ -z "$_mode" ]; then
        _mode="unknown"
    fi
    echo "$_mode"
}


cmd_start() {
    if is_running; then
        _pid=$(cat "$CLASH_PID_FILE" 2>/dev/null)
        log_msg "clash already running (PID $_pid)"
        return 0
    fi

    if [ ! -x "$CLASH_BIN" ]; then
        log_msg "clash binary not found or not executable: $CLASH_BIN"
        echo "Error: clash binary not found at $CLASH_BIN" >&2
        return 1
    fi

    if [ ! -f "$CLASH_CONFIG" ]; then
        log_msg "clash config not found: $CLASH_CONFIG"
        echo "Error: config not found at $CLASH_CONFIG" >&2
        return 1
    fi

    log_msg "starting clash daemon"
    nohup "$CLASH_BIN" -d "$CLASH_DIR" -f "$CLASH_CONFIG" >> "$CLASH_LOG" 2>&1 &
    _new_pid=$!
    echo "$_new_pid" > "$CLASH_PID_FILE"

    _waited=0
    while [ "$_waited" -lt 3 ]; do
        if [ -d "/proc/$_new_pid" ]; then
            break
        fi
        sleep 1
        _waited=$((_waited + 1))
    done

    if [ -d "/proc/$_new_pid" ]; then
        log_msg "clash started successfully (PID $_new_pid)"
        return 0
    else
        log_msg "clash failed to start"
        rm -f "$CLASH_PID_FILE"
        echo "Error: clash process exited during startup" >&2
        return 1
    fi
}

cmd_stop() {
    if ! is_running; then
        log_msg "clash is not running"
        rm -f "$CLASH_PID_FILE"
        return 0
    fi

    _pid=$(cat "$CLASH_PID_FILE" 2>/dev/null)
    log_msg "stopping clash (PID $_pid)"

    kill "$_pid" 2>/dev/null

    _waited=0
    while [ "$_waited" -lt 20 ]; do
        if [ ! -d "/proc/$_pid" ]; then
            break
        fi
        sleep 0.1
        _waited=$((_waited + 1))
    done

    if [ -d "/proc/$_pid" ]; then
        log_msg "clash did not exit gracefully, sending SIGKILL"
        kill -9 "$_pid" 2>/dev/null
        sleep 0.5
    fi

    if [ -d "/proc/$_pid" ]; then
        log_msg "failed to kill clash (PID $_pid)"
        echo "Error: failed to stop clash" >&2
        return 1
    fi

    rm -f "$CLASH_PID_FILE"
    log_msg "clash stopped"
    return 0
}

cmd_restart() {
    cmd_stop
    nohup sh -c 'sleep 3 && /jffs/clash/clash_service.sh start' >> /tmp/clash.log 2>&1 &
    log_msg "restart scheduled: stop done, start in 3s"
}

cmd_status() {
    if ! is_running; then
        echo "stopped"
        return 0
    fi

    _pid=$(cat "$CLASH_PID_FILE" 2>/dev/null)
    _uptime=$(get_uptime_seconds)
    _mode=$(get_mode)

    echo "running|pid=$_pid|uptime=$_uptime|mode=$_mode"
    return 0
}

cmd_set_mode() {
    _new_mode="$1"
    case "$_new_mode" in
        rule|global|direct)
            ;;
        *)
            echo "Usage: $0 set_mode <rule|global|direct>" >&2
            return 1
            ;;
    esac

    _secret=$(get_clash_secret)
    _auth_header=""
    if [ -n "$_secret" ]; then
        _auth_header="Authorization: Bearer $_secret"
    fi

    _payload="{\"mode\":\"$_new_mode\"}"
    _response=""
    if [ -n "$_auth_header" ]; then
        _response=$(curl -s -o /dev/null -w "%{http_code}" \
            -X PATCH \
            -H "Content-Type: application/json" \
            -H "$_auth_header" \
            -d "$_payload" \
            "http://$CLASH_EXT_CTL/configs" 2>/dev/null)
    else
        _response=$(curl -s -o /dev/null -w "%{http_code}" \
            -X PATCH \
            -H "Content-Type: application/json" \
            -d "$_payload" \
            "http://$CLASH_EXT_CTL/configs" 2>/dev/null)
    fi

    if [ "$_response" = "204" ] || [ "$_response" = "200" ]; then
        log_msg "mode set to $_new_mode"
        _verified=$(get_mode)
        if [ "$_verified" = "$_new_mode" ]; then
            echo "ok: mode set to $_new_mode"
            return 0
        else
            echo "warn: API returned success but mode is $_verified"
            return 0
        fi
    else
        log_msg "failed to set mode to $_new_mode (HTTP $_response)"
        echo "Error: failed to set mode (HTTP $_response)" >&2
        return 1
    fi
}

cmd_get_mode() {
    _mode=$(get_mode)
    echo "$_mode"
}

cmd_generate_status_html() {
    if ! is_running; then
        cat <<'HTMLEOF'
<div style="padding:10px;font-family:sans-serif;font-size:13px">
<span style="color:#c00;font-weight:bold">&#9679; Stopped</span>
</div>
HTMLEOF
        return 0
    fi

    _pid=$(cat "$CLASH_PID_FILE" 2>/dev/null)
    _uptime_secs=$(get_uptime_seconds)
    _uptime_fmt=$(format_uptime "$_uptime_secs")
    _mode=$(get_mode)

    cat <<HTMLEOF
<div style="padding:10px;font-family:sans-serif;font-size:13px">
<span style="color:#090;font-weight:bold">&#9679; Running</span> | PID: $_pid | Uptime: $_uptime_fmt | Mode: <b>$_mode</b>
</div>
HTMLEOF
    return 0
}


case "${1:-}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    set_mode)
        cmd_set_mode "$2"
        ;;
    get_mode)
        cmd_get_mode
        ;;
    generate_status_html)
        cmd_generate_status_html
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|set_mode <mode>|get_mode|generate_status_html}" >&2
        exit 1
        ;;
esac
