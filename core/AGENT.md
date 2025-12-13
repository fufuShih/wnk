
# Bun Runtime (core)

This folder contains the Bun/TypeScript runtime that acts like a plugin host.

- It reads JSON lines from stdin.
- When it receives `{ "type": "query", "text": "..." }`, it computes results and prints
	`{ "type": "results", "items": [...] }` as a single line on stdout.

**Calculator plugin**

The calculator is implemented as a results provider:

- Input: the query string from the host.
- Output: zero or one result item (expression evaluation).

