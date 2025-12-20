# What is Wnk?
Wnk is a Raycast-style keyboard launcher built in Zig (`dvui` + SDL3) with a Bun/TypeScript plugin runtime. The Zig host renders the UI and communicates with plugins over newline-delimited JSON, letting plugins like calculator, weather, and todo extend search results and panels.

# Install
1. Install Zig (0.13+ recommended) and Bun.
2. Build the plugins: `cd runtime-bun && bun install && bun run build:plugins`.
3. Build and run the host: `zig build` then `zig build run` (use `zig build test` for tests).
