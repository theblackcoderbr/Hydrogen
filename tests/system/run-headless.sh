#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$project_root/scripts/lib/require-test-environment.sh"
test_root="$(mktemp -d /tmp/hydrogen-system.XXXXXX)"
sway_pid=""
hydrogen_pid=""
app_pids=()

cleanup() {
    for app_pid in "${app_pids[@]}"; do
        kill "$app_pid" 2>/dev/null || true
    done
    [[ -z "$hydrogen_pid" ]] || kill "$hydrogen_pid" 2>/dev/null || true
    [[ -z "$sway_pid" ]] || kill "$sway_pid" 2>/dev/null || true
    if [[ "${HYDROGEN_KEEP_TEST_ROOT:-0}" == "1" ]]; then
        echo "Preserved test artifacts: $test_root" >&2
    else
        rm -rf "$test_root"
    fi
}
trap cleanup EXIT
trap 'exit_code=$?; echo "ERROR: headless assertion failed at line $LINENO (exit $exit_code)." >&2' ERR

find_tool() {
    local name="$1"
    local found
    found="$(command -v "$name" || true)"
    [[ -n "$found" ]] || return 1
    printf '%s\n' "$found"
}

sway_bin="$(find_tool sway)"
swaymsg_bin="$(find_tool swaymsg)"
qs_bin="$(find_tool qs)"

json_value() {
    local expression="$1"
    "$(find_tool node)" -e "const value=JSON.parse(require('fs').readFileSync(0,'utf8')); const result=($expression); process.stdout.write(result !== null && typeof result === 'object' ? JSON.stringify(result) : String(result));"
}

export XDG_CONFIG_HOME="$test_root/config"
export XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache"
export XDG_DATA_HOME="$test_root/data"
export XDG_RUNTIME_DIR="$test_root/runtime"
export WLR_BACKENDS=headless
export WLR_HEADLESS_OUTPUTS=2
export WLR_LIBINPUT_NO_DEVICES=1
export WLR_RENDERER=pixman
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME/applications" "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"
mkdir -p "$XDG_STATE_HOME/hydrogen"
chmod 0700 "$XDG_STATE_HOME/hydrogen"
printf '{corrupted-state' >"$XDG_STATE_HOME/hydrogen/state.json"
chmod 0600 "$XDG_STATE_HOME/hydrogen/state.json"
for ordinal in 01 02 03 04 05; do
    printf '{older-corrupted-state' >"$XDG_STATE_HOME/hydrogen/state.corrupt-2026-08-27T00-00-$ordinal-000Z.json"
done

write_desktop_entry() {
    local id="$1"
    local name="$2"
    local startup_class="${3:-}"
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=true\nIcon=application-x-executable\n' "$name" >"$XDG_DATA_HOME/applications/$id.desktop"
    if [[ -n "$startup_class" ]]; then
        printf 'StartupWMClass=%s\n' "$startup_class" >>"$XDG_DATA_HOME/applications/$id.desktop"
    fi
}

write_desktop_entry org.test.Group "Grupo de teste"
write_desktop_entry org.test.Urgent "Aplicativo urgente"
write_desktop_entry xterm-app "XTerm de teste" XTermClass

"$sway_bin" -c "$project_root/tests/system/sway-headless.conf" -d >"$test_root/sway.log" 2>&1 &
sway_pid=$!

for _ in {1..100}; do
    sway_socket="$(find "$XDG_RUNTIME_DIR" -name 'sway-ipc.*.sock' -print -quit 2>/dev/null || true)"
    [[ -n "$sway_socket" ]] && break
    sleep 0.1
done
[[ -n "${sway_socket:-}" ]] || { cat "$test_root/sway.log"; exit 1; }
export SWAYSOCK="$sway_socket"
wayland_socket="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit)"
export WAYLAND_DISPLAY="$(basename "$wayland_socket")"

"$qs_bin" -p "$project_root/hydrogen" --no-color -v >"$test_root/hydrogen.log" 2>&1 &
hydrogen_pid=$!

status_json=""
for _ in {1..150}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"code":"success"'* ]] && break
    sleep 0.1
done
if [[ "$status_json" != *'"code":"success"'* ]]; then
    cat "$test_root/hydrogen.log"
    exit 1
fi

outputs_json="$("$swaymsg_bin" -r -t get_outputs)"
[[ "$(grep -o '"name"' <<<"$outputs_json" | wc -l)" -eq 2 ]]
[[ "$(json_value 'value.find(output => output.name === "HEADLESS-2").current_mode.width' <<<"$outputs_json")" -eq 1024 ]]
[[ "$(json_value 'value.find(output => output.name === "HEADLESS-2").current_mode.height' <<<"$outputs_json")" -eq 768 ]]
[[ "$status_json" == *'"surface_count":2'* ]]
diagnostics_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 diagnostics)"
diagnostics_data="$(json_value 'value.data' <<<"$diagnostics_json")"
[[ "$(json_value 'value.outputs.length' <<<"$diagnostics_data")" -eq 2 ]]
[[ "$(json_value 'value.outputs.find(output => output.name === "HEADLESS-1").width' <<<"$diagnostics_data")" -eq 1280 ]]
[[ "$(json_value 'value.outputs.find(output => output.name === "HEADLESS-2").width' <<<"$diagnostics_data")" -eq 819 ]]
[[ "$(json_value 'value.outputs.find(output => output.name === "HEADLESS-2").height' <<<"$diagnostics_data")" -eq 614 ]]
[[ "$(json_value 'value.outputs.find(output => output.name === "HEADLESS-2").scale' <<<"$diagnostics_data")" == "1.25" ]]

tree_json="$("$swaymsg_bin" -r -t get_tree)"
workspace_one_height="$(json_value '(function find(node) { if (node.type === "workspace" && node.name === "1") return node.rect.height; for (const child of [...(node.nodes || []), ...(node.floating_nodes || [])]) { const result=find(child); if (result !== undefined) return result; } })(value)' <<<"$tree_json")"
workspace_two_height="$(json_value '(function find(node) { if (node.type === "workspace" && node.name === "2") return node.rect.height; for (const child of [...(node.nodes || []), ...(node.floating_nodes || [])]) { const result=find(child); if (result !== undefined) return result; } })(value)' <<<"$tree_json")"
[[ "$workspace_one_height" -lt 720 ]]
[[ "$workspace_two_height" -lt 768 ]]

focused_output="$(json_value 'value.data.focused_output' <<<"$status_json")"
launcher_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 panel open)"
[[ "$launcher_json" == *'"code":"success"'* ]]
for _ in {1..50}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"overlay_surface_count":1'* ]] && break
    sleep 0.1
done
[[ "$(json_value 'value.data.panel' <<<"$status_json")" == "launcher" ]]
[[ "$(json_value 'value.data.panel_output' <<<"$status_json")" == "$focused_output" ]]
[[ "$(json_value 'value.data.overlay_surface_count' <<<"$status_json")" -eq 1 ]]

if [[ "$focused_output" == "HEADLESS-1" ]]; then
    other_output="HEADLESS-2"
    other_workspace="2"
else
    other_output="HEADLESS-1"
    other_workspace="1"
fi
"$swaymsg_bin" workspace "$other_workspace" >/dev/null
for _ in {1..50}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$(json_value 'value.data.focused_output' <<<"$status_json")" == "$other_output" ]] && break
    sleep 0.1
done
[[ "$(json_value 'value.data.focused_output' <<<"$status_json")" == "$other_output" ]]
[[ "$(json_value 'value.data.panel_output' <<<"$status_json")" == "$focused_output" ]]
[[ "$(json_value 'value.data.overlay_surface_count' <<<"$status_json")" -eq 1 ]]
"$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 panel close >/dev/null
for _ in {1..50}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"overlay_surface_count":0'* ]] && break
    sleep 0.1
done
[[ "$(json_value 'value.data.panel' <<<"$status_json")" == "null" ]]

"$swaymsg_bin" output HEADLESS-2 disable >/dev/null
for _ in {1..80}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"surface_count":1'* ]] && break
    sleep 0.1
done
[[ "$status_json" == *'"surface_count":1'* ]]
"$swaymsg_bin" output HEADLESS-2 enable mode 1024x768 position 1280 0 scale 1.25 >/dev/null
for _ in {1..80}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"surface_count":2'* ]] && break
    sleep 0.1
done
[[ "$status_json" == *'"surface_count":2'* ]]
[[ "$status_json" == *'"actionable_error_count":1'* ]]
[[ -f "$XDG_CONFIG_HOME/hydrogen/config.toml" ]]
[[ -f "$XDG_CONFIG_HOME/hydrogen/config.example.toml" ]]
for component in appearance bar integrations launcher notifications osd; do
    [[ -f "$XDG_CONFIG_HOME/hydrogen/components/$component.toml" ]]
done

appearance_file="$XDG_CONFIG_HOME/hydrogen/components/appearance.toml"
sed -i 's/opacity = 0.92/opacity = 0.85/' "$appearance_file"
for _ in {1..50}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"configuration_generation":2'* ]] && break
    sleep 0.1
done
[[ "$status_json" == *'"configuration_generation":2'* ]]

printf '[appearance]\nopacity = invalid-value\n' >"$appearance_file"
for _ in {1..50}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"actionable_error_count":2'* ]] && break
    sleep 0.1
done
[[ "$status_json" == *'"configuration_generation":2'* ]]
[[ "$status_json" == *'"actionable_error_count":2'* ]]

printf '[appearance]\nopacity = 0.80\nanimation_duration_ms = 150\n' >"$appearance_file"
for _ in {1..50}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"configuration_generation":3'* && "$status_json" == *'"actionable_error_count":1'* ]] && break
    sleep 0.1
done
[[ "$status_json" == *'"configuration_generation":3'* ]]
[[ "$status_json" == *'"actionable_error_count":1'* ]]

rm "$appearance_file"
for _ in {1..50}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"configuration_generation":4'* ]] && break
    sleep 0.1
done
[[ "$status_json" == *'"configuration_generation":4'* ]]

bar_file="$XDG_CONFIG_HOME/hydrogen/components/bar.toml"
printf '\n[[bar.app_matching.rules]]\napp_id = "manual-portable"\nname = "Programa portátil"\nicon = "application-x-executable"\n' >>"$bar_file"
for _ in {1..50}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"configuration_generation":5'* ]] && break
    sleep 0.1
done
[[ "$status_json" == *'"configuration_generation":5'* ]]

spawn_foot() {
    local app_id="$1"
    local title="$2"
    local ordinal="${#app_pids[@]}"
    foot --app-id="$app_id" --title="$title" sleep 120 >"$test_root/foot-$ordinal.log" 2>&1 &
    app_pids+=("$!")
}

"$swaymsg_bin" workspace 1 >/dev/null
spawn_foot org.test.Group "Documento A"
spawn_foot org.test.Group "Documento B"
spawn_foot missing.identity.one "Título igual"
spawn_foot missing.identity.two "Título igual"
spawn_foot manual-portable "Portátil"
for ordinal in {1..8}; do
    spawn_foot "overflow.$ordinal" "Overflow $ordinal"
done
"$swaymsg_bin" exec 'xterm -class XTermClass -name xterm-test -T XWayland -e sleep 120' >/dev/null

for _ in {1..120}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$(json_value 'value.data.window_count' <<<"$status_json")" -ge 14 ]] && break
    sleep 0.1
done
[[ "$(json_value 'value.data.window_count' <<<"$status_json")" -ge 14 ]]

"$swaymsg_bin" workspace 2 >/dev/null
spawn_foot org.test.Urgent "Urgente"
for _ in {1..80}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$(json_value 'value.data.window_count' <<<"$status_json")" -eq 15 ]] && break
    sleep 0.1
done
"$swaymsg_bin" workspace 1 >/dev/null
"$swaymsg_bin" '[app_id="org.test.Urgent"] urgent enable' >/dev/null
for _ in {1..80}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$(json_value 'value.data.urgent_window_count' <<<"$status_json")" -eq 1 ]] && break
    sleep 0.1
done
[[ "$(json_value 'value.data.window_count' <<<"$status_json")" -eq 15 ]]
[[ "$(json_value 'value.data.group_count' <<<"$status_json")" -eq 14 ]]
[[ "$(json_value 'value.data.largest_group_size' <<<"$status_json")" -eq 2 ]]
[[ "$(json_value 'value.data.unresolved_window_count' <<<"$status_json")" -eq 10 ]]
[[ "$(json_value 'value.data.xwayland_window_count' <<<"$status_json")" -eq 1 ]]
[[ "$(json_value 'value.data.urgent_window_count' <<<"$status_json")" -eq 1 ]]

sed -i '/^\[\[bar\.app_matching\.rules\]\]/,$d' "$bar_file"
for _ in {1..60}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"configuration_generation":6'* && "$(json_value 'value.data.unresolved_window_count' <<<"$status_json")" -eq 11 ]] && break
    sleep 0.1
done
[[ "$(json_value 'value.data.unresolved_window_count' <<<"$status_json")" -eq 11 ]]
printf '\n[[bar.app_matching.rules]]\napp_id = "manual-portable"\nname = "Programa portátil"\nicon = "application-x-executable"\n' >>"$bar_file"
for _ in {1..60}; do
    status_json="$("$qs_bin" -p "$project_root/hydrogen" ipc call hydrogen.v1 status 2>/dev/null || true)"
    [[ "$status_json" == *'"configuration_generation":7'* && "$(json_value 'value.data.unresolved_window_count' <<<"$status_json")" -eq 10 ]] && break
    sleep 0.1
done
[[ "$(json_value 'value.data.unresolved_window_count' <<<"$status_json")" -eq 10 ]]

[[ "$(stat -c '%a' "$XDG_STATE_HOME/hydrogen")" == "700" ]]
for state_file in state.json launcher-history.json notification-history.json; do
    state_mode=""
    for _ in {1..50}; do
        if [[ -f "$XDG_STATE_HOME/hydrogen/$state_file" ]]; then
            state_mode="$(stat -c '%a' "$XDG_STATE_HOME/hydrogen/$state_file")"
            [[ "$state_mode" == "600" ]] && break
        fi
        sleep 0.1
    done
    [[ "$state_mode" == "600" ]]
done
corrupt_copy_count=""
for _ in {1..50}; do
    corrupt_copy_count="$(find "$XDG_STATE_HOME/hydrogen" -name 'state.corrupt-*.json' -type f | wc -l)"
    [[ "$corrupt_copy_count" -eq 3 ]] && break
    sleep 0.1
done
[[ "$corrupt_copy_count" -eq 3 ]]
[[ -f "$XDG_STATE_HOME/hydrogen/state.corrupt-2026-08-27T00-00-05-000Z.json" ]]
[[ -f "$XDG_STATE_HOME/hydrogen/state.corrupt-2026-08-27T00-00-04-000Z.json" ]]
[[ ! -e "$XDG_STATE_HOME/hydrogen/state.corrupt-2026-08-27T00-00-03-000Z.json" ]]
grep -q '"schema_version":1' "$XDG_STATE_HOME/hydrogen/state.json"

kill "$sway_pid"
wait "$sway_pid" || true
sway_pid=""
for _ in {1..30}; do
    kill -0 "$hydrogen_pid" 2>/dev/null || break
    sleep 0.1
done
if kill -0 "$hydrogen_pid" 2>/dev/null; then
    cat "$test_root/hydrogen.log"
    exit 1
fi
wait "$hydrogen_pid" || true
hydrogen_pid=""

echo "PASS: Hydrogen validated bars, overlays, hotplug, Wayland/XWayland discovery, grouping, unresolved identities, urgency, overflow pressure, and shutdown."
