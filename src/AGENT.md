
# Zig Host (src)

Zig host UI for the WNK launcher.

## File Structure

```
src/
├── main.zig      - App initialization, render loop, plugin lifecycle
├── plugin.zig    - Bun IPC (stdin/stdout JSON protocol)
├── state/        - Global state
└── ui/
    ├── search.zig                 - Search input + results list
    ├── keyboard.zig               - Event handling & navigation
    ├── panels.zig                 - Panel rendering (list/sub/command)
    ├── floating_action_panel.zig  - Floating action menu
    ├── commands.zig               - Command definitions
    └── components.zig             - Reusable UI helpers
```

## Core Architecture

### Plugin System ([plugin.zig](plugin.zig))

**BunProcess** manages stdin/stdout JSON IPC:

Host → Bun:
- `{ type: "query", text: "..." }`
- `{ type: "command", name: "...", text: "..." }`
- `{ type: "event", name: "..." }`

Bun → Host:
- `{ type: "results", items: [...] }`
- `{ type: "effect", name: "...", text: "..." }`

Methods: `spawn()`, `pollLine()` (non-blocking via `PeekNamedPipe`), `sendQuery()`, `sendCommand()`, `sendEvent()`

### State ([state/mod.zig](state/mod.zig))

Panel modes: `main`, `list`, `sub`, `command`, `action`

Key fields: `search_text`, `plugin_results`, `selected_index`, `focus_on_results`, `panel_mode`

### Main Loop ([main.zig](main.zig))

Window: 700×500px, borderless, 0.95 opacity, always on top (SDL3 + dvui)

Render loop: keyboard events → header → execute commands → send queries → poll Bun → render panels → floating overlay

## UI Layout

### Top Header
- **Main:** search box
- **Others:** panel title + selected item + hints

### Content
- **Main:** results list (plugin + mock, real-time filtered)
- **List/Sub/Command:** respective panel content

### Overlay
- **Action:** floating menu (bottom-right, W/S navigation)

Render order: header → content → floating overlay (if active)

## Panels

| Mode | Description | Enter | K | ESC |
|------|-------------|-------|---|-----|
| main | Search + results | Open list | Action overlay | Exit (if search focused) |
| list | Item details | Action overlay | Action overlay | → main |
| sub | Sub-navigation | - | Action overlay | → main |
| command | Command selection | Execute | - | → main |
| action | Floating overlay | Execute | - | → prev panel |

**Navigation:** Tab (toggle search/results), W/S (navigate), Enter (activate), K (actions), ESC (back)

## Plugin Flow

1. Type query → 2. Send to Bun → 3. Receive results → 4. Update state → 5. Select item → 6. Open list → 7. Press K → 8. Select action → 9. Send command → 10. Receive effect → 11. Apply

## Conventions

- Context in header, not panel body
- Use [ui/components.zig](ui/components.zig) for consistency
- Overlays use absolute positioning
- State-driven rendering only
- Non-blocking I/O via `PeekNamedPipe`

