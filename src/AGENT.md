
# Zig Host (src)

This folder contains the Zig application (the host UI).

- `main.zig`: frame loop, focus handling, and IPC polling.
- `ui/`: search box + results list rendering.
- `plugin/ipc.zig`: manages the Bun child process and reads/writes JSON messages.

**List mode**

The host always draws the same layout (search on top, results panel below).
Plugins only provide data items; the host controls focus/selection and rendering.

**Keyboard behavior**

- `Tab`: toggle focus between search and results.
- `W/S`: move selection when results are focused.
- `Enter`:
	- From search: moves focus into results.
	- From results: activates the selected item (currently accepts the item text into search).

