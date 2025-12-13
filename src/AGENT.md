
# Zig Host (src)

This folder contains the Zig application (the host UI).

- `main.zig`: frame loop, panel composition, command execution side effects, and IPC polling.
- `ui/`: immediate-mode UI modules (search/results/panels/overlays/components).
- `plugin/ipc.zig`: manages the Bun child process and reads/writes JSON messages.

## UI Architecture

The host UI is composed from three conceptual regions:

1) **Top header region** (where the search normally is)
- Main panel: renders the search box.
- Non-main panels: renders a panel header (title + selected item header when relevant) and then a short hint block.

2) **Base content region**
- Main panel: renders the results list.
- List/Sub/Command panels: render panel-specific content.

3) **Overlays**
- The action panel is an overlay (floating popout) anchored to the bottom-right. It does not affect layout.

### Rendering Flow

- `main.zig` decides the current `top_mode` as:
	- if `panel_mode == .action` then `top_mode = prev_panel_mode` (so the header matches the underlying panel)
	- otherwise `top_mode = panel_mode`
- The base panel is rendered inside an overlay container, then the action overlay is rendered on top when active.

## Components & Modules

- `ui/components.zig`: shared UI primitives
	- `beginCard(...)`: standard card container (padding/margins/corners)
	- `heading(...)`: panel heading text
	- `headerTitle(...)` / `headerSubtitle(...)`: selected-item header typography
	- `optionRow(...)`: selectable row styling used by popout menus

- `ui/panels.zig`: panel rendering (non-overlay)
	- `renderTop(mode, selected)`: draws the top header region for non-main panels
	- `renderList(...)`: list panel body (currently minimal; header is in the top region)
	- `renderSub(...)`, `renderCommand(...)`: panel bodies

- `ui/floating_action_panel.zig`: the floating action menu (overlay content)
	- Anchored bottom-right by `main.zig`.
	- Uses `ui.optionRow` for selection styling.

- `ui/commands.zig`: command catalog shared by command/action UIs and execution.

- `ui/search.zig` / `ui/results.zig`: search input and results list.

## Formatting & Conventions

- **Keep panel bodies simple.** Prefer putting “context” (title + selected item header + hints) in the top header region so panels don’t duplicate it.
- **Use shared primitives** from `ui/components.zig` for consistent spacing/typography.
- **Overlays never change layout.** Floating menus (like action) must render in an overlay container and be anchored.
- **State-driven UI only.** Rendering reads from `state.zig`; side effects (command execution / IPC) live in `main.zig`.

## Panels

The host is panel-based. Some panels show the search box; others replace it.

- **Main panel**: search box (top) + results list (below)
- **List panel**: replaces the search box with a heading + item header (actions are a floating overlay)
- **Action panel**: a floating overlay anchored to the bottom-right

When not in the main panel, the host uses the top (search) area as a single header bar:

- Left: a back-arrow title (e.g. "< Calendar")
- Right: one condensed hint string

## Keyboard behavior

- `Tab`: toggle focus between search and results (main panel only)
- `W/S`: move selection in results (main) or the action/command popout menus
- `Enter`:
	- From search: moves focus into results.
	- From results: opens the list panel for the selected item.
	- From list: opens the action panel overlay.
	- From action/command: executes the selected command.
- `Esc`:
	- From list/sub/command: returns to the main panel.
	- From action panel: returns to the previous panel.
- `k`: opens the action panel overlay (when on main results or sub panel)
- `k` also opens the action panel overlay from the list panel

