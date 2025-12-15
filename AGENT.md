# WNK (wnk Launcher)

**Last Updated:** `2025-12-15T02:58:53+08:00`

Launcher-style app with:
- Zig host UI (`dvui` + SDL3 backend) in `src/`
- Bun/TypeScript runtime (plugins + IPC) in `core/`

## Quick Commands
- Build: `zig build`
- Run: `zig build run`
- Test: `zig build test`
- Rebuild plugin bundles: `cd core; bun run build:plugins`

## IPC Protocol (Host <-> Bun)
Messages are newline-delimited JSON over stdin/stdout.

Host -> Bun
- `{ "type": "query", "text": "..." }`
- `{ "type": "getSubpanel", "pluginId": "...", "itemId": "..." }`
- `{ "type": "command", "name": "...", "text": "..." }`

Bun -> Host
- `{ "type": "results", "items": [...] }`
- `{ "type": "subpanel", ... }` (details schema; see `src/mod/state/ipc.zig`)
- `{ "type": "effect", "name": "...", "text": "..." }`

## Notes
- The Bun runtime imports built plugin bundles from `core/plugins/*/dist/`; update TS sources then run `bun run build:plugins`.
- The Zig host currently uses Windows non-blocking pipe reads (`PeekNamedPipe`), so behavior is most tested on Windows.
