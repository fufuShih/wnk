# Bun Runtime (core)

**Last Updated:** `2025-12-15T02:58:53+08:00`

This folder contains the Bun/TypeScript runtime that:
- reads newline-delimited JSON from stdin (from the Zig host)
- writes newline-delimited JSON to stdout (back to the host)
- aggregates plugin results/subpanels

## Quick Commands
- Start runtime (expects host input): `cd core; bun run start`
- Rebuild plugin bundles: `cd core; bun run build:plugins`

## Runtime Entry
- `core/runtime.tsx` routes messages:
  - `query` -> merges plugin `getResults(...)` output and emits `results`
  - `getSubpanel` -> emits `subpanel` (used by the host details panel)
  - `command` -> may emit `effect` (e.g. `setSearchText`)

## Plugins
- Source: `core/plugins/*/src/`
- Built bundles (imported by `runtime.tsx`): `core/plugins/*/dist/bundle.js`
- Each plugin bundle exports functions used by the runtime (e.g. `getResults`, optional `getSubpanel`).
