#!/bin/sh
# Manage Clash/Mihomo configs on ASUSWRT-Merlin (POSIX sh / busybox ash)

CLASH_DIR="/jffs/clash"
CLASH_CONFIG="$CLASH_DIR/config.yaml"
CLASH_LOG="/tmp/clash.log"

log_msg() {
    logger -t "clash-webui" "$1"
}

validate_filename() {
    case "$1" in
        ..|../*|*/..|*/../*) return 1 ;;
        */*) return 1 ;;
        -*) return 1 ;;
    esac
    case "$1" in
        *.yaml|*.yml) return 0 ;;
        *) return 1 ;;
    esac
}

html_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

do_list() {
    for f in "$CLASH_DIR"/*.yaml "$CLASH_DIR"/*.yml; do
        [ -f "$f" ] && basename "$f"
    done 2>/dev/null
}

do_current() {
    local resolved
    resolved=$(readlink -f "$CLASH_CONFIG" 2>/dev/null || echo "$CLASH_CONFIG")
    basename "$resolved"
}

do_switch() {
    local filename="$1"
    if [ -z "$filename" ]; then
        echo "Error: filename required"
        return 1
    fi
    if ! validate_filename "$filename"; then
        echo "Error: invalid filename"
        log_msg "Rejected invalid filename in switch: $filename"
        return 1
    fi
    if [ ! -f "$CLASH_DIR/$filename" ]; then
        echo "Error: file not found: $filename"
        return 1
    fi

    cp "$CLASH_CONFIG" "${CLASH_CONFIG}.bak"
    cp "$CLASH_DIR/$filename" "$CLASH_CONFIG"
    log_msg "Switched config to: $filename"

    if [ -x "$CLASH_DIR/clash_service.sh" ]; then
        "$CLASH_DIR/clash_service.sh" restart
    fi
}

do_save() {
    local b64_content="$1"
    if [ -z "$b64_content" ]; then
        echo "Error: no content provided"
        return 1
    fi

    local decoded
    decoded=$(echo "$b64_content" | base64 -d 2>/dev/null)
    if [ -z "$decoded" ]; then
        echo "Error: failed to decode base64 content"
        return 1
    fi

    cp "$CLASH_CONFIG" "${CLASH_CONFIG}.bak"
    echo "$b64_content" | base64 -d > "$CLASH_CONFIG"
    log_msg "Saved new config via web UI"

    if [ -x "$CLASH_DIR/clash_service.sh" ]; then
        "$CLASH_DIR/clash_service.sh" restart
    fi
}

do_upload_save() {
    local filename="$1"
    local b64_content="$2"

    if [ -z "$filename" ] || [ -z "$b64_content" ]; then
        echo "Error: filename and content required"
        return 1
    fi
    if ! validate_filename "$filename"; then
        echo "Error: invalid filename"
        log_msg "Rejected invalid filename in upload: $filename"
        return 1
    fi

    echo "$b64_content" | base64 -d > "$CLASH_DIR/$filename"
    log_msg "Uploaded config file: $filename"
}

do_show() {
    if [ -f "$CLASH_CONFIG" ]; then
        cat "$CLASH_CONFIG"
    else
        echo "Error: config file not found"
    fi
}

do_logs() {
    local lines="${1:-100}"
    if [ -f "$CLASH_LOG" ]; then
        tail -n "$lines" "$CLASH_LOG" 2>/dev/null
    else
        echo "No logs available"
    fi
}

do_clear_logs() {
    : > "$CLASH_LOG"
    log_msg "Cleared clash log file"
}

do_generate_config_list_html() {
    local current
    current=$(do_current)

    for f in "$CLASH_DIR"/*.yaml "$CLASH_DIR"/*.yml; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f")
        if [ "$name" = "$current" ]; then
            printf '<option value="%s" selected>%s</option>\n' "$name" "$name"
        else
            printf '<option value="%s">%s</option>\n' "$name" "$name"
        fi
    done 2>/dev/null
}

do_generate_config_content_html() {
    printf '<pre style="background:#1a1a1a;color:#ccc;padding:15px;font-size:12px;overflow:auto;max-height:500px;border:1px solid #444;">\n'
    if [ -f "$CLASH_CONFIG" ]; then
        html_escape < "$CLASH_CONFIG"
    else
        printf 'Error: config file not found'
    fi
    printf '\n</pre>\n'
}

do_generate_logs_html() {
    local lines="${1:-100}"
    printf '<div style="font-family:monospace;background:#1a1a1a;color:#ccc;padding:10px;font-size:11px;overflow:auto;max-height:400px;border:1px solid #444;white-space:pre-wrap;">\n'
    if [ -f "$CLASH_LOG" ]; then
        tail -n "$lines" "$CLASH_LOG" 2>/dev/null | html_escape
    else
        printf 'No logs available'
    fi
    printf '\n</div>\n'
}

case "$1" in
    list)
        do_list
        ;;
    current)
        do_current
        ;;
    switch)
        do_switch "$2"
        ;;
    save)
        do_save "$2"
        ;;
    upload_save)
        do_upload_save "$2" "$3"
        ;;
    show)
        do_show
        ;;
    logs)
        do_logs "$2"
        ;;
    clear_logs)
        do_clear_logs
        ;;
    generate_config_list_html)
        do_generate_config_list_html
        ;;
    generate_config_content_html)
        do_generate_config_content_html
        ;;
    generate_logs_html)
        do_generate_logs_html "$2"
        ;;
    *)
        echo "Usage: $0 {list|current|switch|save|show|logs|clear_logs|upload_save|generate_config_list_html|generate_config_content_html|generate_logs_html}"
        exit 1
        ;;
esac
