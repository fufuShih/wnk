# Bun Runtime (runtime-bun)

**Last Updated:** `2025-12-15T02:58:53+08:00`

This folder contains the Bun/TypeScript runtime that:
- reads newline-delimited JSON from stdin (from the Zig host)
- writes newline-delimited JSON to stdout (back to the host)
- aggregates plugin results/panels

## Quick Commands
- Start runtime (expects host input): `cd runtime-bun; bun run start`
- Rebuild plugin bundles: `cd runtime-bun; bun run build:plugins`

## Runtime Entry
- `runtime-bun/runtime.tsx` routes messages:
  - `query` -> merges plugin `getResults(...)` output and emits `results`
  - `getPanel` -> emits `panel` (used by the host details panel)
  - `command` -> may emit `effect` (e.g. `setSearchText`)

## Plugins
- Source: `runtime-bun/plugins/*/src/`
- Built bundles (imported by `runtime.tsx`): `runtime-bun/plugins/*/dist/bundle.js`
- Each plugin bundle exports functions used by the runtime (e.g. `getResults`, optional `getPanel`).
- Plugins declare metadata in `runtime-bun/plugins/*/manifest.json` (loaded by the runtime).
