#!/bin/sh
# install.sh — Install Clash WebUI addon for ASUSWRT-Merlin
# Compatible with busybox ash (POSIX sh)

CLASH_DIR="/jffs/clash"
ADDON_NAME="clash_webui"
ASP_PAGE="clash.asp"
TITLE="Clash"
MENU_TAB_NAME="Clash"

log_msg() {
    logger -t "clash-webui" "$1"
}

print_status() {
    printf "[clash-webui] %s\n" "$1"
}

check_firmware() {
    if ! nvram get rc_support | grep -q "am_addons"; then
        print_status "ERROR: Firmware does not support Addons API (am_addons)."
        print_status "Requires ASUSWRT-Merlin 384.15 or later."
        exit 1
    fi
}

check_scripts() {
    if [ ! -f "$CLASH_DIR/clash_service.sh" ]; then
        print_status "ERROR: $CLASH_DIR/clash_service.sh not found."
        exit 1
    fi
    if [ ! -f "$CLASH_DIR/clash_config.sh" ]; then
        print_status "ERROR: $CLASH_DIR/clash_config.sh not found."
        exit 1
    fi
    if [ ! -f "$CLASH_DIR/$ASP_PAGE" ]; then
        print_status "ERROR: $CLASH_DIR/$ASP_PAGE not found."
        exit 1
    fi
    chmod 755 "$CLASH_DIR/clash_service.sh" "$CLASH_DIR/clash_config.sh"
}

mount_webui_page() {
    _old_page=$(cat "$CLASH_DIR/.webui_page" 2>/dev/null)
    if [ -n "$_old_page" ] && [ -f "/www/user/$_old_page" ]; then
        rm -f "/www/user/$_old_page"
        rm -f "/www/user/$(echo "$_old_page" | cut -f1 -d'.').title"
    fi

    source /usr/sbin/helper.sh

    am_get_webui_page "$CLASH_DIR/$ASP_PAGE"
    if [ "$am_webui_page" = "none" ]; then
        print_status "ERROR: No available WebUI page slot (all 20 slots in use)."
        exit 1
    fi

    print_status "Allocated page slot: $am_webui_page"
    cp -f "$CLASH_DIR/$ASP_PAGE" "/www/user/$am_webui_page"
    echo "$am_webui_page" > "$CLASH_DIR/.webui_page"

    _title_file="/www/user/$(echo "$am_webui_page" | cut -f1 -d'.').title"
    echo "$TITLE" > "$_title_file"
}

inject_menu() {
    _page=$(cat "$CLASH_DIR/.webui_page" 2>/dev/null)
    if [ -z "$_page" ]; then
        print_status "WARNING: Could not determine page slot, skipping menu injection."
        return
    fi

    if [ ! -f /tmp/menuTree.js ]; then
        cp -f /www/require/modules/menuTree.js /tmp/
    fi

    sed -i "\~$_page~d" /tmp/menuTree.js

    sed -i "/url: \"Tools_OtherSettings.asp\", tabName:/i \\
{url: \"$_page\", tabName: \"$MENU_TAB_NAME\"}," /tmp/menuTree.js

    umount /www/require/modules/menuTree.js 2>/dev/null
    mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js

    cp -f /tmp/menuTree.js "$CLASH_DIR/.menuTree_backup"
    print_status "Injected '$MENU_TAB_NAME' tab into Tools menu."
}

setup_html_dir() {
    mkdir -p /www/user/clash
    "$CLASH_DIR/clash_config.sh" generate_config_list_html > /www/user/clash/config_list.html
    "$CLASH_DIR/clash_config.sh" generate_config_content_html > /www/user/clash/config.html
    print_status "Generated HTML fragments in /www/user/clash/"
}

register_service_event() {
    _hook_file="/jffs/scripts/service-event"
    _marker_start="### $ADDON_NAME start"
    _marker_end="### $ADDON_NAME end"

    if [ ! -f "$_hook_file" ]; then
        printf '#!/bin/sh\n' > "$_hook_file"
        chmod 755 "$_hook_file"
    fi

    if grep -q "$_marker_start" "$_hook_file" 2>/dev/null; then
        print_status "service-event hook already registered."
        return
    fi

    printf '\n%s\n' "$_marker_start" >> "$_hook_file"
    cat >> "$_hook_file" <<'HANDLER'
if [ "$1" = "restart" ] && [ "$2" = "clash" ]; then
    source /usr/sbin/helper.sh
    _action=$(am_settings_get clash_webui_action)
    am_settings_set clash_webui_action ""

    case "$_action" in
        start)
            /jffs/clash/clash_service.sh start
            ;;
        stop)
            /jffs/clash/clash_service.sh stop
            ;;
        restart)
            /jffs/clash/clash_service.sh restart
            ;;
        switch)
            _cfg=$(am_settings_get clash_webui_switch_config)
            /jffs/clash/clash_config.sh switch "$_cfg"
            ;;
        install_dashboard)
            mkdir -p /jffs/clash/dashboard
            curl -sL 'https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz' | tar xz -C /jffs/clash/dashboard
            grep -q '^external-ui:' /jffs/clash/config.yaml || echo 'external-ui: /jffs/clash/dashboard' >> /jffs/clash/config.yaml
            /jffs/clash/clash_service.sh restart
            ;;
        save_settings)
            ;;
        *)
            /jffs/clash/clash_service.sh restart
            ;;
    esac

    mkdir -p /www/user/clash
    /jffs/clash/clash_config.sh generate_config_list_html > /www/user/clash/config_list.html
    /jffs/clash/clash_config.sh generate_config_content_html > /www/user/clash/config.html
fi
HANDLER
    printf '%s\n' "$_marker_end" >> "$_hook_file"

    chmod 755 "$_hook_file"
    print_status "Registered service-event hook."
}

register_services_start() {
    _hook_file="/jffs/scripts/services-start"
    _marker_start="### $ADDON_NAME start"
    _marker_end="### $ADDON_NAME end"

    if [ ! -f "$_hook_file" ]; then
        printf '#!/bin/sh\n' > "$_hook_file"
        chmod 755 "$_hook_file"
    fi

    if grep -q "$_marker_start" "$_hook_file" 2>/dev/null; then
        print_status "services-start hook already registered."
        return
    fi

    printf '\n%s\n' "$_marker_start" >> "$_hook_file"
    cat >> "$_hook_file" <<'BOOTHOOK'
source /usr/sbin/helper.sh
nvram get rc_support | grep -q am_addons || exit 0

_am_page=$(cat /jffs/clash/.webui_page 2>/dev/null)
if [ -n "$_am_page" ] && [ -f "/jffs/clash/clash.asp" ]; then
    cp -f /jffs/clash/clash.asp "/www/user/$_am_page"
    echo "Clash" > "/www/user/$(echo "$_am_page" | cut -f1 -d'.').title"

    if [ ! -f /tmp/menuTree.js ]; then
        cp -f /www/require/modules/menuTree.js /tmp/
    fi
    sed -i "\~$_am_page~d" /tmp/menuTree.js
    sed -i "/url: \"Tools_OtherSettings.asp\", tabName:/i \\
{url: \"$_am_page\", tabName: \"Clash\"}," /tmp/menuTree.js
    umount /www/require/modules/menuTree.js 2>/dev/null
    mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
fi

mkdir -p /www/user/clash
/jffs/clash/clash_config.sh generate_config_list_html > /www/user/clash/config_list.html 2>/dev/null
/jffs/clash/clash_config.sh generate_config_content_html > /www/user/clash/config.html 2>/dev/null

_auto_start=$(am_settings_get clash_webui_auto_start 2>/dev/null)
if [ "$_auto_start" = "1" ]; then
    /jffs/clash/clash_service.sh start
fi
BOOTHOOK
    printf '%s\n' "$_marker_end" >> "$_hook_file"

    chmod 755 "$_hook_file"
    print_status "Registered services-start hook."
}

set_default_settings() {
    source /usr/sbin/helper.sh

    _existing=$(am_settings_get clash_webui_secret 2>/dev/null)
    if [ -z "$_existing" ]; then
        _secret=""
        if [ -f "$CLASH_DIR/config.yaml" ]; then
            _secret=$(grep '^secret:' "$CLASH_DIR/config.yaml" 2>/dev/null | awk '{print $2}')
        fi
        am_settings_set clash_webui_secret "$_secret"
        am_settings_set clash_webui_auto_start "1"
        am_settings_set clash_webui_dashboard_url ""
        am_settings_set clash_webui_action ""
        print_status "Set default settings."
    else
        print_status "Settings already exist, keeping current values."
    fi
}

echo ""
echo "============================================="
echo "  Clash WebUI for ASUSWRT-Merlin - Installer"
echo "============================================="
echo ""

check_firmware
check_scripts

print_status "Creating required directories..."
mkdir -p /jffs/addons
mkdir -p /jffs/scripts
mkdir -p /www/user
mkdir -p /www/user/clash

print_status "Mounting WebUI page..."
mount_webui_page

print_status "Injecting menu entry..."
inject_menu

print_status "Setting up HTML fragments..."
setup_html_dir

print_status "Registering service hooks..."
register_service_event
register_services_start

print_status "Configuring default settings..."
set_default_settings

echo ""
print_status "Installation complete!"
print_status "Access Clash WebUI: http://$(nvram get lan_ipaddr)/$(cat $CLASH_DIR/.webui_page)"
print_status "Menu location: Tools -> $MENU_TAB_NAME"
echo ""
