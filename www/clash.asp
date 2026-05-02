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

.clash-log-viewer {
    background-color: #1a1a1a;
    border: 1px solid #444;
    color: #cccccc;
    font-family: 'Courier New', Courier, monospace;
    font-size: 11px;
    padding: 12px;
    overflow-y: auto;
    max-height: 400px;
    white-space: pre-wrap;
    word-wrap: break-word;
    width: 100%;
    -webkit-overflow-scrolling: touch;
}

.clash-config-editor {
    width: 100%;
    min-height: 350px;
    background-color: #1a1a1a;
    border: 1px solid #444;
    color: #cccccc;
    font-family: 'Courier New', Courier, monospace;
    font-size: 12px;
    padding: 10px;
    resize: vertical;
    -webkit-overflow-scrolling: touch;
}
.clash-config-editor:focus {
    outline: none;
    border-color: #557788;
}

.clash-dashboard-frame {
    width: 100%;
    height: 500px;
    border: 1px solid #444;
    background-color: #1a1a1a;
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

.clash-upload-row {
    padding: 6px 0;
}
.clash-upload-row input[type="file"] {
    color: #ccc;
    font-size: 12px;
    font-family: Arial, Helvetica, sans-serif;
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
var logRefreshTimer = null;
var autoRefreshLogs = false;
var dashboardVisible = false;

function initial() {
    SetCurrentPage();
    show_menu();
    loadCustomSettings();
    restoreCheckboxState();
    updateStatus();
    loadConfigList();
    loadDashboardSettings();
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
    document.getElementById('SystemCmd').value = "";
    document.form.action_script.value = "restart_clash";
    document.form.action_wait.value = wait || "5";
    showLoading();
    document.form.submit();
}

function submitSystemCmd(cmd, wait) {
    document.getElementById('SystemCmd').value = cmd;
    document.getElementById('amng_custom').value = "";
    document.form.action_script.value = "";
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
    $.ajax({
        url: '/user/clash/config.html',
        type: 'GET',
        timeout: 5000,
        cache: false,
        success: function(data) {
            $('#configContent').html(data);
        },
        error: function() {
            $('#configContent').html('<div style="padding:10px;color:#c00;">Failed to load configuration.</div>');
        }
    });
}

function editCurrentConfig() {
    $.ajax({
        url: '/user/clash/config.html',
        type: 'GET',
        timeout: 5000,
        cache: false,
        success: function(data) {
            var temp = document.createElement('div');
            temp.innerHTML = data;
            var rawText = temp.textContent || temp.innerText || '';
            document.getElementById('configEditor').value = rawText;
        },
        error: function() {
            alert('Failed to load configuration for editing.');
        }
    });
}

function saveConfig() {
    var content = document.getElementById('configEditor').value;
    if (!content || !content.length) {
        alert('Configuration content is empty.');
        return;
    }
    if (!confirm('Save and apply this configuration? This will restart Clash.')) {
        return;
    }
    var b64 = btoa(unescape(encodeURIComponent(content)));
    var cmd = "echo '" + b64 + "' | base64 -d > /tmp/clash_webui_config.tmp && " +
        "cp /jffs/clash/config.yaml /jffs/clash/config.yaml.bak && " +
        "mv /tmp/clash_webui_config.tmp /jffs/clash/config.yaml && " +
        "/jffs/clash/clash_service.sh restart && " +
        "/jffs/clash/clash_config.sh generate_config_list_html > /www/user/clash/config_list.html && " +
        "/jffs/clash/clash_config.sh generate_config_content_html > /www/user/clash/config.html";
    submitSystemCmd(cmd, "10");
}

function uploadConfig() {
    var fileInput = document.getElementById('configUploadFile');
    if (!fileInput.files || !fileInput.files.length) {
        alert('Please select a file to upload.');
        return;
    }
    var file = fileInput.files[0];
    var fileName = file.name;
    if (!fileName.match(/\.ya?ml$/i)) {
        alert('Only .yaml and .yml files are allowed.');
        return;
    }
    var reader = new FileReader();
    reader.onload = function(e) {
        var b64Content = e.target.result.split(',')[1];
        if (!b64Content) {
            alert('Failed to read file content.');
            return;
        }
        var cmd = "echo '" + b64Content + "' | base64 -d > /jffs/clash/" + fileName + " && " +
            "/jffs/clash/clash_config.sh generate_config_list_html > /www/user/clash/config_list.html";
        submitSystemCmd(cmd, "5");
    };
    reader.readAsDataURL(file);
}

/* ── Logs viewer ── */
function refreshLogs() {
    $.ajax({
        url: '/user/clash/logs.html',
        type: 'GET',
        timeout: 5000,
        cache: false,
        success: function(data) {
            $('#logsArea').html(data);
            var logsDiv = document.getElementById('logsArea');
            logsDiv.scrollTop = logsDiv.scrollHeight;
        },
        error: function() {
            $('#logsArea').html('<div style="padding:10px;color:#c00;">Failed to load logs.</div>');
        }
    });
}

function clearLogs() {
    if (!confirm('Clear all Clash logs?')) {
        return;
    }
    submitAction("clear_logs", "3");
}

function toggleAutoRefreshLogs() {
    autoRefreshLogs = document.getElementById('autoRefreshLogsChk').checked;
    if (autoRefreshLogs) {
        refreshLogs();
        logRefreshTimer = setInterval(refreshLogs, 3000);
    } else {
        if (logRefreshTimer) {
            clearInterval(logRefreshTimer);
            logRefreshTimer = null;
        }
    }
}

/* ── Dashboard ── */
function loadDashboardSettings() {
    var url = custom_settings.clash_webui_dashboard_url || '';
    document.getElementById('dashboardUrlInput').value = url;
}

function toggleDashboard() {
    if (dashboardVisible) {
        $('#dashboardContainer').hide();
        $('#dashboardToggleBtn').val('Open Dashboard');
        dashboardVisible = false;
    } else {
        var url = document.getElementById('dashboardUrlInput').value;
        if (!url) {
            url = 'http://' + location.hostname + ':9090/ui';
            document.getElementById('dashboardUrlInput').value = url;
        }
        document.getElementById('dashboardFrame').src = url;
        $('#dashboardContainer').show();
        $('#dashboardToggleBtn').val('Close Dashboard');
        dashboardVisible = true;
    }
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
    <input type="hidden" name="SystemCmd" id="SystemCmd" value="">

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
                    <!-- Section B: Service Controls              -->
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
                    <!-- Section C: Proxy Mode Selector           -->
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
                    <!-- Section D: Configuration Management      -->
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

                    <!-- View current config -->
                    <div style="margin-bottom:8px;">
                        <input type="button" class="button_gen" value="View Current Config" onclick="viewCurrentConfig();">
                        <input type="button" class="button_gen" value="Edit Config" onclick="editCurrentConfig();" style="margin-left:8px;">
                    </div>
                    <div id="configContent" style="margin-bottom:12px;"></div>

                    <!-- Config editor textarea -->
                    <div id="configEditorWrap" style="margin-bottom:10px;">
                        <div style="color:#8f8f8f;font-size:11px;font-family:Arial,Helvetica,sans-serif;margin-bottom:4px;">
                            Edit configuration below, then click Save to apply:
                        </div>
                        <textarea id="configEditor" class="clash-config-editor" rows="18" spellcheck="false"></textarea>
                        <div style="margin-top:6px;">
                            <input type="button" class="button_gen" value="Save &amp; Apply" onclick="saveConfig();">
                        </div>
                    </div>

                    <!-- Upload config -->
                    <div class="clash-upload-row">
                        <span style="color:#fff;font-size:12px;font-family:Arial,Helvetica,sans-serif;">Upload new config:</span>
                        <input type="file" id="configUploadFile" accept=".yaml,.yml" style="margin:0 8px;">
                        <input type="button" class="button_gen" value="Upload" onclick="uploadConfig();">
                    </div>

                    <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                    <!-- ──────────────────────────────────────── -->
                    <!-- Section E: Logs Viewer                   -->
                    <!-- ──────────────────────────────────────── -->
                    <div class="clash-section-header">Logs</div>
                    <div class="clash-section-desc">View Clash runtime logs.</div>

                    <div style="margin-bottom:6px;">
                        <input type="button" class="button_gen" value="Refresh Logs" onclick="refreshLogs();">
                        <input type="button" class="button_gen" value="Clear Logs" onclick="clearLogs();" style="margin-left:6px;">
                        <label style="color:#fff;font-size:12px;font-family:Arial,Helvetica,sans-serif;margin-left:12px;cursor:pointer;">
                            <input type="checkbox" id="autoRefreshLogsChk" onchange="toggleAutoRefreshLogs();" style="vertical-align:middle;margin-right:4px;">
                            Auto-refresh
                        </label>
                    </div>

                    <div id="logsArea" class="clash-log-viewer">Click "Refresh Logs" to load.</div>

                    <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                    <!-- ──────────────────────────────────────── -->
                    <!-- Section F: Dashboard (iframe)            -->
                    <!-- ──────────────────────────────────────── -->
                    <div class="clash-section-header">Dashboard</div>
                    <div class="clash-section-desc">Open an external Clash dashboard (Yacd / MetaCubeXD) in an embedded frame.</div>

                    <table width="100%" border="0" cellpadding="4" cellspacing="0" style="margin-bottom:8px;">
                    <tr>
                        <td width="30%" style="color:#fff;font-size:12px;font-family:Arial,Helvetica,sans-serif;">Dashboard URL:</td>
                        <td>
                            <input type="text" id="dashboardUrlInput" class="input_25_table" style="width:340px;" placeholder="http://router-ip:9090/ui">
                            <input type="button" class="button_gen" value="Save URL" onclick="saveDashboardUrl();" style="margin-left:8px;">
                        </td>
                    </tr>
                    </table>

                    <div style="margin-bottom:8px;">
                        <input type="button" id="dashboardToggleBtn" class="button_gen clash-toggle-btn" value="Open Dashboard" onclick="toggleDashboard();">
                    </div>

                    <div id="dashboardContainer" style="display:none;">
                        <iframe id="dashboardFrame" class="clash-dashboard-frame" src="" frameborder="0"></iframe>
                    </div>

                    <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                    <!-- ──────────────────────────────────────── -->
                    <!-- Section G: Settings                      -->
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
