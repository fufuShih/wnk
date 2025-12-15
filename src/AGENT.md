# Zig Host (src)

**Last Updated:** `2025-12-15T02:58:53+08:00`

Zig host UI for the WNK launcher (dvui + SDL3).

## Quick Commands
- Build: `zig build`
- Run: `zig build run`
- Test: `zig build test`
- Format: `zig fmt src build.zig`

## Structure
```
src/
  main.zig           - App init, frame loop, panel transitions
  plugin.zig         - Bun IPC (stdin/stdout JSON protocol)
  mod/
    state/           - Global state + IPC payload parsing
    tray/            - System tray integration
  ui/
    search.zig       - Search input + results list
    keyboard.zig     - Input handling & navigation
    panel/
      top.zig        - Panel top header rendering
      main.zig       - Panel main content rendering + overlay
      bottom.zig     - Panel bottom hint bar
    floating_action_panel.zig
    commands.zig     - Command definitions and UI
    components.zig   - Shared UI helpers
```

## IPC
- Host spawns Bun via `plugin.BunProcess.spawn()` and sends `query`, `getSubpanel`, and `command`.
- Incoming messages are handled in `state.handleBunMessage()` (results/subpanel/effects).

## UI Conventions
- Keep rendering state-driven (avoid hidden global UI state).
- Put context in the header area; keep panels focused on content/actions.
