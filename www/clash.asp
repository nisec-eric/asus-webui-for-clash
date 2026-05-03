<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
<meta HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>Clash WebUI</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<style type="text/css">
/* ── Clash WebUI custom styles (complements ASUS theme) ── */

.clash-status-badge {
    display: inline-block;
    padding: 4px 12px;
    border-radius: 3px;
    font-size: 12px;
    font-weight: bold;
    font-family: Arial, Helvetica, sans-serif;
    vertical-align: middle;
}
.clash-status-badge.running {
    background-color: #2d4a2d;
    color: #6fcf6f;
    border: 1px solid #3a6b3a;
}
.clash-status-badge.stopped {
    background-color: #4a2d2d;
    color: #cf6f6f;
    border: 1px solid #6b3a3a;
}
.clash-status-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    margin-right: 6px;
    vertical-align: middle;
}
.clash-status-dot.green {
    background-color: #6fcf6f;
    box-shadow: 0 0 4px #6fcf6f;
}
.clash-status-dot.red {
    background-color: #cf6f6f;
    box-shadow: 0 0 4px #cf6f6f;
}

.clash-info-row {
    padding: 4px 0;
    font-size: 12px;
    font-family: Arial, Helvetica, sans-serif;
    color: #fff;
}
.clash-info-row span.label {
    color: #8f8f8f;
    margin-right: 6px;
}

.clash-controls-bar {
    margin: 8px 0 12px 0;
    padding: 10px 0;
    border-top: 1px solid #334;
    border-bottom: 1px solid #334;
}

.clash-section-header {
    font-size: 13px;
    font-weight: bold;
    color: #ffffff;
    font-family: Arial, Helvetica, sans-serif;
    padding: 8px 0 4px 0;
    margin: 0;
}
.clash-section-desc {
    font-size: 11px;
    color: #8f8f8f;
    font-family: Arial, Helvetica, sans-serif;
    padding: 2px 0 8px 0;
}

.clash-btn-group {
    margin: 4px 0;
}
.clash-btn-group input[type="button"],
.clash-btn-group input[type="submit"] {
    margin-right: 6px;
}

.clash-toggle-btn {
    cursor: pointer;
}
</style>

<script type="text/javascript" src="/js/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/js/httpApi.js"></script>
<script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
<script type="text/javascript" language="JavaScript" src="/validator.js"></script>

<script type="text/javascript">
var custom_settings = {};
var statusRefreshTimer = null;
var dashboardInstalled = false;

function initial() {
    SetCurrentPage();
    show_menu();
    loadCustomSettings();
    restoreCheckboxState();
    updateStatus();
    loadConfigList();
    loadDashboardSettings();
    checkDashboardInstalled();
}

function SetCurrentPage() {
    document.form.next_page.value = window.location.pathname.substring(1);
    document.form.current_page.value = window.location.pathname.substring(1);
}

function loadCustomSettings() {
    custom_settings = <% get_custom_settings(); %>;
    for (var prop in custom_settings) {
        if (prop.indexOf("clash_webui") === -1) {
            delete custom_settings[prop];
        } else if (typeof custom_settings[prop] === 'string') {
            custom_settings[prop] = custom_settings[prop].replace(/^\s+|\s+$/g, '');
        }
    }
}

function restoreCheckboxState() {
    var autoStart = custom_settings.clash_webui_auto_start;
    if (autoStart && autoStart.replace(/\s/g, '') === '1') {
        document.getElementById('autoStartChk').checked = true;
    }
    if (custom_settings.clash_webui_secret) {
        document.getElementById('secretInput').value = custom_settings.clash_webui_secret;
    }
}

function getApiUrl(path) {
    return 'http://' + location.hostname + ':9090' + path;
}

function getApiHeaders() {
    var headers = { 'Content-Type': 'application/json' };
    var secret = custom_settings.clash_webui_secret || '';
    if (secret) {
        headers['Authorization'] = 'Bearer ' + secret;
    }
    return headers;
}

function submitAction(action, wait) {
    custom_settings.clash_webui_action = action;
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = "restart_clash";
    document.form.action_wait.value = wait || "5";
    showLoading();
    document.form.submit();
}

/* ── Status panel (queries clash REST API directly) ── */
function updateStatus() {
    $.ajax({
        url: getApiUrl('/version'),
        type: 'GET',
        headers: getApiHeaders(),
        timeout: 4000,
        success: function() {
            $.ajax({
                url: getApiUrl('/configs'),
                type: 'GET',
                headers: getApiHeaders(),
                timeout: 4000,
                success: function(data) {
                    var mode = data.mode || 'unknown';
                    $('#statusArea').html(
                        '<div style="padding:8px;font-family:Arial,Helvetica,sans-serif;font-size:13px">' +
                        '<span class="clash-status-dot green"></span>' +
                        '<span class="clash-status-badge running">Running</span>' +
                        '&nbsp;&nbsp;Mode: <b>' + mode + '</b>' +
                        '</div>'
                    );
                },
                error: function() {
                    $('#statusArea').html(
                        '<div style="padding:8px;font-family:Arial,Helvetica,sans-serif;font-size:13px">' +
                        '<span class="clash-status-dot green"></span>' +
                        '<span class="clash-status-badge running">Running</span>' +
                        '</div>'
                    );
                }
            });
        },
        error: function() {
            $('#statusArea').html(
                '<div style="padding:8px;font-family:Arial,Helvetica,sans-serif;font-size:13px">' +
                '<span class="clash-status-dot red"></span>' +
                '<span class="clash-status-badge stopped">Stopped</span>' +
                '</div>'
            );
        },
        complete: function() {
            if (statusRefreshTimer) clearTimeout(statusRefreshTimer);
            statusRefreshTimer = setTimeout(updateStatus, 5000);
        }
    });
}

/* ── Service controls ── */
function startClash() {
    submitAction("start", "5");
}

function stopClash() {
    submitAction("stop", "3");
}

function restartClash() {
    submitAction("restart", "8");
}

/* ── Proxy mode selector ── */
function applyMode() {
    var mode = document.getElementById('clashModeSelect').value;
    if (!mode) {
        alert('Please select a mode.');
        return;
    }
    $.ajax({
        url: getApiUrl('/configs'),
        type: 'PATCH',
        headers: getApiHeaders(),
        data: JSON.stringify({ mode: mode }),
        timeout: 5000,
        success: function() {
            updateStatus();
        },
        error: function(xhr, textStatus) {
            alert('Failed to set mode. Clash may not be running. (' + textStatus + ')');
        }
    });
}

/* ── Configuration management ── */
function loadConfigList() {
    $.ajax({
        url: '/user/clash/config_list.html',
        type: 'GET',
        timeout: 5000,
        cache: false,
        success: function(data) {
            $('#clashConfigSelect').html(data);
        },
        error: function() {
            $('#clashConfigSelect').html('<option value="">Unable to load configs</option>');
        }
    });
}

function switchConfig() {
    var selectedFile = document.getElementById('clashConfigSelect').value;
    if (!selectedFile) {
        alert('Please select a configuration file.');
        return;
    }
    if (!confirm('Switch to ' + selectedFile + ' and restart Clash?')) {
        return;
    }
    custom_settings.clash_webui_switch_config = selectedFile;
    submitAction("switch", "10");
}

function viewCurrentConfig() {
    var el = document.getElementById('configContent');
    if (!el) return;
    if (el.style.display === 'block') {
        el.style.display = 'none';
        return;
    }
    $.ajax({
        url: '/user/clash/config.html',
        type: 'GET',
        timeout: 15000,
        cache: false,
        success: function(data) {
            el.innerHTML = data;
            el.style.display = 'block';
            var pre = el.getElementsByTagName('pre')[0];
            if (pre) {
                var text = pre.innerHTML;
                var lines = text.split('\n');
                var html = '';
                for (var i = 0; i < lines.length; i++) {
                    var num = i + 1;
                    html += '<span style="display:inline-block;width:40px;color:#666;text-align:right;padding-right:10px;user-select:none;-webkit-user-select:none;">' + num + '</span>' + lines[i] + '\n';
                }
                pre.innerHTML = html;
            }
        },
        error: function(xhr) {
            el.innerHTML = '<div style="padding:10px;color:#c00;">Failed to load. Status: ' + (xhr ? xhr.status : 'unknown') + '</div>';
            el.style.display = 'block';
        }
    });
}

function loadDashboardSettings() {
    var url = custom_settings.clash_webui_dashboard_url || '';
    if (!url) {
        url = 'http://' + location.hostname + ':9090/ui';
    }
    document.getElementById('dashboardUrlInput').value = url;
}

function checkDashboardInstalled() {
    var dashUrl = 'http://' + location.hostname + ':9090/ui/';
    $.ajax({
        url: dashUrl,
        type: 'GET',
        timeout: 3000,
        success: function(data) {
            dashboardInstalled = true;
            $('#dashboardStatus').html('<span style="color:#6fcf6f;font-weight:bold;">Installed</span>');
            $('#dashboardOpenBtn').show();
            $('#dashboardInstallBtn').hide();
        },
        error: function(xhr) {
            if (xhr.status === 200) {
                dashboardInstalled = true;
                $('#dashboardStatus').html('<span style="color:#6fcf6f;font-weight:bold;">Installed</span>');
                $('#dashboardOpenBtn').show();
                $('#dashboardInstallBtn').hide();
                return;
            }
            dashboardInstalled = false;
            $('#dashboardStatus').html('<span style="color:#cf6f6f;">Not installed</span>');
            $('#dashboardOpenBtn').hide();
            $('#dashboardInstallBtn').show();
        }
    });
}

function installDashboard() {
    if (!confirm('Download MetaCubeXD dashboard from GitHub and install to /jffs/clash/dashboard?\n\nThis will also add external-ui to config.yaml and restart Clash.')) {
        return;
    }
    submitAction("install_dashboard", "15");
}

function openDashboard() {
    var url = document.getElementById('dashboardUrlInput').value;
    if (!url) {
        url = 'http://' + location.hostname + ':9090/ui';
        document.getElementById('dashboardUrlInput').value = url;
    }
    window.open(url, '_blank');
}

function saveDashboardUrl() {
    var url = document.getElementById('dashboardUrlInput').value;
    custom_settings.clash_webui_dashboard_url = url;
    submitAction("save_settings", "3");
}

/* ── Auto-start toggle ── */
function toggleAutoStart() {
    var checked = document.getElementById('autoStartChk').checked;
    custom_settings.clash_webui_auto_start = checked ? '1' : '0';
    submitAction("save_settings", "3");
}

/* ── API secret ── */
function saveSecret() {
    var secret = document.getElementById('secretInput').value;
    custom_settings.clash_webui_secret = secret;
    submitAction("save_settings", "3");
}
</script>
</head>

<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>

<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

<form method="post" name="form" action="start_apply.htm" target="hidden_frame">
    <input type="hidden" name="current_page" value="">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="modified" value="0">
    <input type="hidden" name="action_mode" value="apply">
    <input type="hidden" name="action_wait" value="5">
    <input type="hidden" name="first_time" value="">
    <input type="hidden" name="action_script" value="">
    <input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
    <input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
<input type="hidden" name="amng_custom" id="amng_custom" value="">


    <table class="content" align="center" cellpadding="0" cellspacing="0">
    <tr>
        <td width="17">&nbsp;</td>
        <td valign="top" width="202">
            <div id="mainMenu"></div>
            <div id="subMenu"></div>
        </td>
        <td valign="top">
            <div id="tabMenu" class="submenuBlock"></div>

            <!-- ════════════════════════════════════════════════════ -->
            <!-- Main content area                                    -->
            <!-- ════════════════════════════════════════════════════ -->
            <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
            <tr><td align="left" valign="top">
                <table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
                <tr><td bgcolor="#4D595D" colspan="3" valign="top">

                    <div>&nbsp;</div>
                    <div class="formfonttitle">Clash</div>
                    <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                    <!-- ──────────────────────────────────────── -->
                    <!-- Section A: Status Panel                  -->
                    <!-- ──────────────────────────────────────── -->
                    <div class="clash-section-header">Service Status</div>
                    <div class="clash-section-desc">Current state of the Clash proxy daemon.</div>
                    <div id="statusArea" style="margin-bottom:6px;">
                        <div style="padding:10px;font-family:sans-serif;font-size:13px;color:#8f8f8f;">
                            Loading status...
                        </div>
                    </div>

                    <!-- ──────────────────────────────────────── -->
                    <!-- Section B: Dashboard                     -->
                    <!-- ──────────────────────────────────────── -->
                    <div class="clash-section-header">Dashboard</div>
                    <div class="clash-section-desc">Clash dashboard (MetaCubeXD) for proxy visualization and management.</div>

                    <table width="100%" border="0" cellpadding="4" cellspacing="0" style="margin-bottom:8px;">
                    <tr>
                        <td width="30%" style="color:#fff;font-size:12px;font-family:Arial,Helvetica,sans-serif;">Status:</td>
                        <td>
                            <span id="dashboardStatus" style="font-size:12px;font-family:Arial,Helvetica,sans-serif;">Checking...</span>
                        </td>
                    </tr>
                    <tr>
                        <td width="30%" style="color:#fff;font-size:12px;font-family:Arial,Helvetica,sans-serif;">Dashboard URL:</td>
                        <td>
                            <input type="text" id="dashboardUrlInput" class="input_25_table" style="width:340px;" placeholder="http://router-ip:9090/ui">
                            <input type="button" class="button_gen" value="Save URL" onclick="saveDashboardUrl();" style="margin-left:8px;">
                        </td>
                    </tr>
                    </table>

                    <div style="margin-bottom:8px;">
                        <input type="button" id="dashboardInstallBtn" class="button_gen" value="Install Dashboard" onclick="installDashboard();" style="display:none;">
                        <input type="button" id="dashboardOpenBtn" class="button_gen clash-toggle-btn" value="Open Dashboard" onclick="openDashboard();" style="display:none;">
                    </div>

                    <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                    <!-- ──────────────────────────────────────── -->
                    <!-- Section C: Service Controls              -->
                    <!-- ──────────────────────────────────────── -->
                    <div class="clash-controls-bar">
                        <div class="clash-section-header">Service Controls</div>
                        <div class="clash-section-desc">Start, stop, or restart the Clash service.</div>
                        <div class="clash-btn-group" style="padding-top:4px;">
                            <input type="button" class="button_gen" value="Start" onclick="startClash();">
                            <input type="button" class="button_gen" value="Stop" onclick="stopClash();">
                            <input type="button" class="button_gen" value="Restart" onclick="restartClash();">
                        </div>
                        <div style="margin-top:8px;">
                            <label style="color:#fff;font-size:12px;font-family:Arial,Helvetica,sans-serif;cursor:pointer;">
                                <input type="checkbox" id="autoStartChk"
                                    onchange="toggleAutoStart();"
                                    style="vertical-align:middle;margin-right:4px;">
                                Auto-start Clash on boot
                            </label>
                        </div>
                    </div>

                    <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                    <!-- ──────────────────────────────────────── -->
                    <!-- Section D: Proxy Mode Selector           -->
                    <!-- ──────────────────────────────────────── -->
                    <div class="clash-section-header">Proxy Mode</div>
                    <div class="clash-section-desc">Select how Clash routes traffic. Requires Clash API to be reachable.</div>
                    <table width="100%" border="0" cellpadding="4" cellspacing="0" style="margin-bottom:10px;">
                    <tr>
                        <td width="30%" style="color:#fff;font-size:12px;font-family:Arial,Helvetica,sans-serif;">Mode:</td>
                        <td>
                            <select id="clashModeSelect" class="input_option" style="width:200px;">
                                <option value="rule" selected>Rule-based</option>
                                <option value="global">Global</option>
                                <option value="direct">Direct</option>
                            </select>
                            <input type="button" class="button_gen" value="Apply Mode" onclick="applyMode();" style="margin-left:8px;">
                        </td>
                    </tr>
                    </table>

                    <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                    <!-- ──────────────────────────────────────── -->
                    <!-- Section E: Configuration Management      -->
                    <!-- ──────────────────────────────────────── -->
                    <div class="clash-section-header">Configuration</div>
                    <div class="clash-section-desc">Manage Clash configuration files stored in /jffs/clash/.</div>

                    <!-- Config file selector -->
                    <table width="100%" border="0" cellpadding="4" cellspacing="0" class="FormTable" style="margin-bottom:10px;">
                    <tr>
                        <td class="FormTableDesc" width="30%">Config File:</td>
                        <td>
                            <select id="clashConfigSelect" class="input_option" style="width:240px;">
                                <option value="">Loading...</option>
                            </select>
                            <input type="button" class="button_gen" value="Switch Config" onclick="switchConfig();" style="margin-left:8px;">
                        </td>
                    </tr>
                    </table>

                    <!-- View config -->
                    <div style="margin-bottom:8px;">
                        <input type="button" class="button_gen" value="View Config" onclick="viewCurrentConfig();">
                    </div>
                    <div id="configContent" style="display:none;margin-bottom:10px;max-width:100%;overflow:auto;"></div>

                    <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                    <!-- ──────────────────────────────────────── -->
                    <!-- Section F: Settings                      -->
                    <!-- ──────────────────────────────────────── -->
                    <div class="clash-section-header">API Settings</div>
                    <div class="clash-section-desc">Clash RESTful API secret for authentication.</div>

                    <table width="100%" border="0" cellpadding="4" cellspacing="0" class="FormTable" style="margin-bottom:10px;">
                    <tr>
                        <td class="FormTableDesc" width="30%">API Secret:</td>
                        <td>
                            <input type="password" id="secretInput" class="input_25_table" style="width:260px;" autocomplete="off">
                            <input type="button" class="button_gen" value="Save Secret" onclick="saveSecret();" style="margin-left:8px;">
                        </td>
                    </tr>
                    </table>

                    <div>&nbsp;</div>
                </table>
            </td></tr>
            </table>
        </td>
    </tr>
    </table>

    <div id="footer"></div>
</form>
</body>
</html>
