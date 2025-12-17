// ============================================
// Todo Plugin
// Session-only todo list rendered via subpanel box layout.
// - Select "Todo List" to open
// - Type "todo <text>" then Enter to add
// - In details, press `k` to open the actions overlay and toggle items
// ============================================

export type ResultItem = {
  id?: string;
  title: string;
  subtitle?: string;
  icon?: string;
};

export type SubpanelItem = {
  id?: string;
  title: string;
  subtitle: string;
};

export type ActionItem = {
  name: string;
  title: string;
  text?: string;
  close_on_execute?: boolean;
};

export type PanelTop = { type: 'header'; title: string; subtitle?: string } | { type: 'selected' };
export type PanelBottom = { type: 'none' } | { type: 'info'; text: string };

export type PanelNode =
  | { type: 'flex'; items: SubpanelItem[] }
  | { type: 'grid'; columns?: number; gap?: number; items: SubpanelItem[] }
  | { type: 'box'; dir?: 'vertical' | 'horizontal'; gap?: number; children: PanelNode[] };

export type SubpanelData = {
  top: PanelTop;
  main: PanelNode;
  bottom?: PanelBottom;
};

type Todo = { id: number; text: string; done: boolean };

const ADD_PREFIX = 'add:';
const CHECK_EMPTY = '\u2610'; // ☐
const CHECK_DONE = '\u2611'; // ☑

let nextId = 1;
let todos: Todo[] = [
  { id: nextId++, text: 'Try toggling me (press k)', done: false },
  { id: nextId++, text: 'Type "todo Buy milk" to add', done: false },
];

function isCommandQuery(query: string): boolean {
  return query.trim().toLowerCase().startsWith('todo');
}

function parseAddFromQuery(query: string): string | null {
  const m = query.trim().match(/^todo\s+(.+)$/i);
  if (!m) return null;
  const text = m[1].trim();
  return text.length > 0 ? text : null;
}

function addTodo(text: string): void {
  const t = text.trim();
  if (!t) return;
  todos.push({ id: nextId++, text: t, done: false });
}

function toggleById(raw: string): void {
  const id = Number.parseInt((raw ?? '').trim(), 10);
  if (!Number.isFinite(id)) return;

  const todo = todos.find((t) => t.id === id);
  if (!todo) return;
  todo.done = !todo.done;
}

function renderSubpanel(): SubpanelData {
  const done = todos.filter((t) => t.done).length;
  const pending = todos.length - done;

  const items: SubpanelItem[] = todos.map((t) => ({
    id: String(t.id),
    title: `${t.done ? CHECK_DONE : CHECK_EMPTY} ${t.text}`,
    subtitle: '',
  }));

  return {
    top: { type: 'header', title: 'Todo', subtitle: `${pending} pending \u00b7 ${done} done (session only)` },
    main: {
      type: 'box',
      dir: 'vertical',
      gap: 12,
      children: [{ type: 'flex', items }],
    },
    bottom: { type: 'info', text: 'W/S: move  Enter: open/actions  k: actions  Esc: back  |  Add: type "todo <text>"' },
  };
}

export function getResults(query: string): ResultItem[] {
  const trimmed = query.trim();
  const addText = parseAddFromQuery(query);
  const cmd = isCommandQuery(query);

  const listSubtitle =
    !trimmed ? 'Open checklist (session only)' :
    trimmed.toLowerCase() === 'todo' ? 'Open checklist (session only)' :
    cmd ? query : 'Open checklist (session only)';

  const list: ResultItem[] = [{ id: 'list', title: 'Todo List', subtitle: listSubtitle, icon: 'T' }];

  if (addText) {
    list.unshift({
      id: `${ADD_PREFIX}${addText}`,
      title: `Add Todo: ${addText}`,
      subtitle: query,
      icon: '+',
    });
  }

  return list;
}

export async function getSubpanel(itemId: string): Promise<SubpanelData | null> {
  if (itemId.startsWith(ADD_PREFIX)) {
    addTodo(itemId.slice(ADD_PREFIX.length));
    return renderSubpanel();
  }

  if (itemId === 'list') return renderSubpanel();
  return null;
}

export function getActions(ctx: {
  panel: 'search' | 'details';
  pluginId: string;
  itemId: string;
  selectedId?: string;
  selectedText?: string;
  query?: string;
}): ActionItem[] {
  if (ctx.panel !== 'details') return [];
  if (ctx.itemId !== 'list') return [];

  return todos.map((t) => ({
    name: 'todo.toggle',
    title: `${t.done ? CHECK_DONE : CHECK_EMPTY} ${t.text}`,
    text: String(t.id),
    close_on_execute: false,
  }));
}

export function onCommand(name: string, text: string): SubpanelData | null {
  if (name === 'toggle') {
    toggleById(text ?? '');
    return renderSubpanel();
  }
  return null;
}

export default function TodoPlugin(): null {
  return null;
}
