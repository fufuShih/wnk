# WNK (wnk Launcher)

**Last Updated:** `2025-12-15T02:58:53+08:00`

Launcher-style app with:
- Zig host UI (`dvui` + SDL3 backend) in `src/`
- Bun/TypeScript runtime (plugins + IPC) in `runtime-bun/`

## Quick Commands
- Build: `zig build`
- Run: `zig build run`
- Test: `zig build test`
- Rebuild plugin bundles: `cd runtime-bun; bun run build:plugins`

## IPC Protocol (Host <-> Bun)
Messages are newline-delimited JSON over stdin/stdout.

Host -> Bun
- `{ "type": "query", "text": "..." }`
- `{ "type": "getPanel", "pluginId": "...", "itemId": "..." }`
- `{ "type": "command", "name": "...", "text": "..." }`
- `{ "type": "getActions", "token": 1, "panel": "search" | "details", "pluginId": "...", "itemId": "...", "selectedId": "...", "selectedText": "...", "query": "..." }`

Bun -> Host
- `{ "type": "results", "items": [...] }`
- `{ "type": "panel", ... }` (details schema; see `src/mod/state/ipc.zig`)
- `{ "type": "actions", "token": 1, "pluginId": "...", "items": [...] }`
- `{ "type": "effect", "name": "...", "text": "..." }`

## Notes
- The Bun runtime imports built plugin bundles from `runtime-bun/plugins/*/dist/`; update TS sources then run `bun run build:plugins`.
- The Zig host uses platform-specific non-blocking pipe reads (`PeekNamedPipe` on Windows, `poll` on POSIX).
