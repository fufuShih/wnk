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
    panels/          - Panel renderers (top/main/bottom in one file each)
      mod.zig        - Panel dispatcher (renderTop/renderMain/renderBottom)
      search.zig     - Search panel (top/main/bottom)
      details.zig    - Details panel (top/main/bottom)
    overlays/        - Floating UI (not a panel region)
      action_overlay.zig
    regions.zig      - Region-scoped UI primitives (top/main/bottom)
    style.zig        - Shared UI styling constants
    search.zig       - Search query + selection helpers
    keyboard.zig     - Input handling & navigation
    actions.zig      - Action overlay context helpers (hasCommand/canOpenOverlay)
    commands.zig     - Command definitions (sent to Bun)
```

## IPC
- Host spawns Bun via `plugin.BunProcess.spawn()` and sends `query`, `getSubpanel`, and `command`.
- Incoming messages are handled in `state.handleBunMessage()` (results/subpanel/effects).

## UI Conventions
- Keep rendering state-driven (avoid hidden global UI state).
- Split each panel into top/main/bottom regions and keep region APIs separated (`ui/regions.zig`).
- The action overlay is not a panel/region: it only opens when main content is focused and the current selection provides actions.
