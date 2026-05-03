#!/bin/sh
# Manage Clash/Mihomo configs on ASUSWRT-Merlin (POSIX sh / busybox ash)

CLASH_DIR="/jffs/clash"
CLASH_CONFIG="$CLASH_DIR/config.yaml"

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

do_show() {
    if [ -f "$CLASH_CONFIG" ]; then
        cat "$CLASH_CONFIG"
    else
        echo "Error: config file not found"
    fi
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
    printf '%s\n' '<pre style="background:#1a1a1a;color:#ccc;padding:15px;font-size:12px;max-height:500px;overflow-y:auto;border:1px solid #444;white-space:pre-wrap;word-wrap:break-word;margin:0;">'
    if [ -f "$CLASH_CONFIG" ]; then
        html_escape < "$CLASH_CONFIG"
    else
        printf 'Error: config file not found'
    fi
    printf '\n</pre>\n'
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
    show)
        do_show
        ;;
    generate_config_list_html)
        do_generate_config_list_html
        ;;
    generate_config_content_html)
        do_generate_config_content_html
        ;;
    *)
        echo "Usage: $0 {list|current|switch|show|generate_config_list_html|generate_config_content_html}"
        exit 1
        ;;
esac
