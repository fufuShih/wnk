
# WNK (Wink Launcher)

This repository is a small launcher-style app.

- The UI is written in Zig using `dvui` + the SDL backend.
- A Bun runtime process provides plugin results over stdin/stdout.

**Runtime flow (high level)**

- User types in the search box.
- The Zig host sends `{ "type": "query", "text": "..." }` to the Bun process.
- Bun responds with one JSON line: `{ "type": "results", "items": [...] }`.
- The host renders results in a fixed “list mode” panel (plugin does not render the UI tree).

**Current plugin**

- Calculator: type an expression and you will get a single result item.
- When focus is on results, pressing Enter “accepts” the selected item into the search input.

