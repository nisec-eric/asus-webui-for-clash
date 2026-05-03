#!/bin/sh
# uninstall.sh — Remove Clash WebUI addon from ASUSWRT-Merlin
# Compatible with busybox ash (POSIX sh)

CLASH_DIR="/jffs/clash"
ADDON_NAME="clash_webui"

log_msg() {
    logger -t "clash-webui" "$1"
}

print_status() {
    printf "[clash-webui] %s\n" "$1"
}

remove_webui_page() {
    rm -f /www/user/user*.asp
    rm -f /www/user/user*.title
    rm -f "$CLASH_DIR/.webui_page"
    print_status "Removed all user page slots."
}

remove_menu_entry() {
    _page=$(cat "$CLASH_DIR/.webui_page" 2>/dev/null)
    if [ -z "$_page" ]; then
        return
    fi

    if [ -f /tmp/menuTree.js ]; then
        sed -i "\~$_page~d" /tmp/menuTree.js
        umount /www/require/modules/menuTree.js 2>/dev/null
        mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
        print_status "Removed menu entry from menuTree.js."
    fi
}

remove_html_dir() {
    if [ -d /www/user/clash ]; then
        rm -rf /www/user/clash
        print_status "Removed /www/user/clash/ HTML fragments."
    fi
}

unregister_service_event() {
    _hook_file="/jffs/scripts/service-event"
    _marker_start="### $ADDON_NAME start"
    _marker_end="### $ADDON_NAME end"

    if [ ! -f "$_hook_file" ]; then
        return
    fi

    if ! grep -q "$_marker_start" "$_hook_file" 2>/dev/null; then
        return
    fi

    _start_line=$(grep -n "$_marker_start" "$_hook_file" | head -1 | cut -f1 -d':')
    _end_line=$(grep -n "$_marker_end" "$_hook_file" | head -1 | cut -f1 -d':')

    if [ -n "$_start_line" ] && [ -n "$_end_line" ]; then
        sed -i "$_start_line,${_end_line}d" "$_hook_file"
        print_status "Removed service-event hook."
    fi
}

unregister_services_start() {
    _hook_file="/jffs/scripts/services-start"
    _marker_start="### $ADDON_NAME start"
    _marker_end="### $ADDON_NAME end"

    if [ ! -f "$_hook_file" ]; then
        return
    fi

    if ! grep -q "$_marker_start" "$_hook_file" 2>/dev/null; then
        return
    fi

    _start_line=$(grep -n "$_marker_start" "$_hook_file" | head -1 | cut -f1 -d':')
    _end_line=$(grep -n "$_marker_end" "$_hook_file" | head -1 | cut -f1 -d':')

    if [ -n "$_start_line" ] && [ -n "$_end_line" ]; then
        sed -i "$_start_line,${_end_line}d" "$_hook_file"
        print_status "Removed services-start hook."
    fi
}

clean_settings() {
    if [ -f /usr/sbin/helper.sh ]; then
        source /usr/sbin/helper.sh
        for key in clash_webui_secret clash_webui_auto_start clash_webui_dashboard_url \
                   clash_webui_action clash_webui_switch_config; do
            am_settings_set "$key" "" 2>/dev/null
        done
        print_status "Cleaned custom_settings entries."
    fi
}

clean_backup_files() {
    rm -f "$CLASH_DIR/.webui_page"
    rm -f "$CLASH_DIR/.menuTree_backup"
    print_status "Cleaned backup files."
}

echo ""
echo "==============================================="
echo "  Clash WebUI for ASUSWRT-Merlin - Uninstaller"
echo "==============================================="
echo ""

if [ "$1" != "-y" ]; then
    printf "Are you sure you want to uninstall Clash WebUI? [y/N] "
    read _confirm
    case "$_confirm" in
        y|Y) ;;
        *) print_status "Cancelled."; exit 0 ;;
    esac
fi

print_status "Removing WebUI page..."
remove_webui_page

print_status "Removing menu entry..."
remove_menu_entry

print_status "Removing HTML fragments..."
remove_html_dir

print_status "Unregistering service hooks..."
unregister_service_event
unregister_services_start

print_status "Cleaning settings..."
clean_settings
clean_backup_files

echo ""
print_status "Uninstallation complete."
print_status "Note: Clash binary and configuration files in $CLASH_DIR were NOT removed."
print_status "Note: clash_service.sh and clash_config.sh were NOT removed."
echo ""
