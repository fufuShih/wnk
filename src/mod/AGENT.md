# Zig Modules (src/mod)

**Last Updated:** `2025-12-15T02:58:53+08:00`

This directory contains Zig modules imported by the host executable via `build.zig`.

## Modules
- `src/mod/context/` - host context capture pipeline (selection, app metadata)
- `src/mod/selection/` - OS selection capture (platform-specific)
- `src/mod/state/` - global state, navigation, and Bun IPC payload parsing
- `src/mod/tray/` - system tray integration (Windows-focused)

Keep module boundaries clean: UI code should live under `src/ui/`, while shared state/IPC belongs in `src/mod/state/`.
