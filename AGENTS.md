# PROJECT KNOWLEDGE BASE

**Target**: ASUSWRT-Merlin router addon (POSIX sh + ASP/jQuery)
**Runtime**: busybox ash on /jffs/clash/, served by mini_httpd

## STRUCTURE

```
./
├── clash_service.sh    # Clash daemon lifecycle (start/stop/restart/status/mode)
├── clash_config.sh     # Config file CRUD + HTML fragment generation
├── install.sh          # Page mounting, menu injection, hook registration
├── uninstall.sh        # Reverse of install
└── www/
    └── clash.asp       # Single-file WebUI (HTML+CSS+JS, 719 lines)
```

## WHERE TO LOOK

| Task | File | Function/Section |
|------|------|-------------------|
| Change service lifecycle | `clash_service.sh` | `cmd_start`, `cmd_stop`, `cmd_restart` |
| Add config operation | `clash_config.sh` | case block at bottom |
| Change UI layout | `www/clash.asp` | HTML after `class="FormTitle"` |
| Change UI behavior | `www/clash.asp` | JS functions in `<script>` block |
| Add new action from WebUI | All 3 files | ASP `submitAction()` → install.sh service-event handler → clash_service.sh |
| Fix menu injection | `install.sh` | `inject_menu()` — sed on menuTree.js |
| Fix boot restore | `install.sh` | services-start heredoc in `register_services_start()` |

## CROSS-FILE CALL GRAPH

```
clash.asp (browser)
  ├── submitAction("start|stop|restart|switch|clear_logs|save_settings")
  │     → action_script="restart_clash" → /jffs/scripts/service-event
  │       → reads clash_webui_action from custom_settings
  │         → dispatches to clash_service.sh or clash_config.sh
  │
  ├── submitSystemCmd(cmd)  [for saveConfig, uploadConfig]
  │     → SystemCmd field → direct shell execution by httpd
  │
  ├── AJAX → http://router:9090/configs  [status, mode switch]
  │
  └── AJAX → /user/clash/*.html  [config list, config content, logs]

clash_config.sh switch → calls clash_service.sh restart
clash_config.sh save   → calls clash_service.sh restart
install.sh services-start → calls clash_config.sh generate_* + clash_service.sh start
```

## CONVENTIONS

- **POSIX sh only**: `#!/bin/sh`, `_var` prefix for function-scoped vars, no `[[ ]]`, no arrays
- `local` keyword accepted (busybox ash supports it despite not being POSIX)
- All router paths are `/jffs/clash/` — configurable via `CLASH_DIR` at top of each script
- No file-based logs — Clash daemon output goes to `/dev/null`; status via REST API only
- Settings via `/jffs/addons/custom_settings.txt` (8KB limit) — accessed via `am_settings_get/set`
- `action_script` on this firmware ONLY triggers service-event with `restart_*` prefix
- Large data (config save/upload) bypasses custom_settings via `SystemCmd` form field

## ANTI-PATTERNS

- **NEVER** use `jQuery.noConflict()` — breaks scrollbar on 388.x firmware
- **NEVER** use `fetch()`, arrow functions, template literals, `const/let` in ASP JS
- **NEVER** save large content (>1KB) through `amng_custom`/custom_settings — use SystemCmd
- **NEVER** use action_script values other than `restart_clash` — firmware only passes `restart_*` to service-event
- **NEVER** write logs or temp files to `/jffs/` — it's small persistent flash, use `/tmp/`
- **NEVER** use bash-specific features — target is busybox ash
- **NEVER** hardcode router IP in ASP — use `location.hostname`

## RESTART MECHANISM

`cmd_restart` in clash_service.sh does NOT call cmd_start synchronously. It backgrounds a delayed start:
```sh
cmd_stop
nohup sh -c 'sleep 3 && /jffs/clash/clash_service.sh start' > /dev/null 2>&1 &
```
This is intentional — synchronous stop→start in the same process context fails on the router.

## DEPLOYMENT

Files go flat into `/jffs/clash/` on the router (ASP page at `www/clash.asp` in repo → `/jffs/clash/clash.asp` on router). `install.sh` copies ASP to `/www/user/user{N}.asp` and bind-mounts modified `menuTree.js`.

Prerequisites: clash binary + config.yaml must already exist in `/jffs/clash/`.
