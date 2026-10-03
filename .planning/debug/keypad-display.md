---
status: awaiting_human_test
trigger: elevator input and teleport work but floor/digits/password are absent from physical display
---

## Flow inspected

Manifest loads bridge then DUI client, runtime and admin menus. Admin captures
keypad model/transform via gizmo and stores interact_coords through server menu.
Runtime fetches elevator/floor data, spawns props, registers interaction, requests
floor input, checks access server-side, requests password, then teleports. Display
messages are independent: Elevator SetKeypadDisplay -> bridge DUI sendMessage ->
SendDuiMessage -> ui/script.js textContent -> runtime texture replacement on keypad.
Bridge URL/create/send/replacement contracts match Elevator calls. Shared UI serves
both overlay (mouse crosshair) and physical DUI texture. No observed access/cache
failure explains missing display with successful input/teleport.

## Evidence and hypothesis

ui/script.js DOMContentLoaded unconditionally hides .keypad, discarding a previous
KEYPAD=true message; only display text is cached. Styles/font stylesheets require
external CDNs and can delay document readiness past fixed Lua sync retries. The
bridge's IsDuiAvailable is not an acknowledgement that this page's DOM is ready.
Texture replacement and model mapping still require real-game visual confirmation.

## Current Focus

2026-10-03 follow-up: user reports the panel now displays SUCCESS, but also when
the password is wrong. This identifies a separate confirmed sequencing issue:
ConfirmCode accepted arbitrary input and showed success before the main runtime
callback checked server access. Added validateInput before success, server-driven
floor/password verdicts, retry without closing, busy guard and session invalidation.
The missing menu.invalid_password key was supplied. All four locale files now
share 190 keys. See docs/AUTHENTICATION_AND_LOCALES.md for verification and UAT.
Current next action: verify wrong/correct password display and the four languages
in FiveM. The earlier blank-texture diagnosis below is historical, not the active
symptom reported in this follow-up. No general live texture test is claimed.

next_action: collect prelevator_dui_status output and temporary
prelevator_dui_preview screenshot with the keypad open. User confirmed the
physical display is still blank after the previous changes. DOM regression tests
are not proof of a working live texture replacement. Compare browser/runtime
preview with the physical model before changing texture names or rendering logic.

The current screenshot retains original faint LCD segments and the * key rather
than the HTML S key. This suggests the original model texture remains visible,
but does not establish whether browser output or replacement failed. The upstream
Colbss/colbss_keypad client uses the same model/dictionary/texture. Added native
availability, actual opened model and runtime texture diagnostics plus a Bridge
sprite preview that stops after ten seconds. No input is logged.

## Fix and verification

Original JS failed dui_page_test.cjs: early KEYPAD=true -> DOMContentLoaded resulted
in display:none. Fixed by storing visibility as well as text and distinguishing
?dui=1 (physical texture) from the default overlay URL (mouse crosshair). DUI is
visible by default and sends keypadDuiReady only after DOM initialization; Lua
resends current visibility/text through the existing bridge instance. External CSS/
fonts removed to prevent remote CDN dependencies from blocking startup; bundled
background and system monospace remain, with bounded text sizing for long prompts.
Normal fullscreen NUI remains hidden. Added diagnostic command without input/password
values. JS ignores malformed message payloads.

actual Lua module integration tests cover create/replace/message contract, floor
input/correction/confirmation, password transition, late readiness and reset. DOM
test covers before/after load, overlay isolation and callback. All Lua files pass
luac; Lua/JS tests and node syntax check passed. No Bridge/XT/server/data changes,
no FXServer restart, and no confirmed live texture mapping test performed.
