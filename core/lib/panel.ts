import type { ReactNode } from 'react';
import type { SerializedNode } from '../sdk/types';
import type { ActionItem, PanelBottom, PanelData, PanelItem, PanelNode, PanelTop } from '../sdk/ipc';
import { renderOnce } from './render-once';

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function asString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

function asFiniteNumber(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function parsePanelTop(value: unknown): PanelTop | undefined {
  if (!isObject(value)) return;
  const type = asString(value.type);
  if (type === 'selected') return { type: 'selected' };
  if (type !== 'header') return;
  const title = asString(value.title);
  if (!title) return;
  const subtitle = asString(value.subtitle);
  return subtitle ? { type: 'header', title, subtitle } : { type: 'header', title };
}

function parsePanelBottom(value: unknown): PanelBottom | undefined {
  if (!isObject(value)) return;
  const type = asString(value.type);
  if (type === 'none') return { type: 'none' };
  if (type !== 'info') return;
  const text = asString(value.text);
  if (text === undefined) return;
  return { type: 'info', text };
}

function parseActions(value: unknown): ActionItem[] | undefined {
  if (!Array.isArray(value)) return;
  const out: ActionItem[] = [];
  for (const v of value) {
    if (!isObject(v)) continue;
    const name = asString(v.name);
    const title = asString(v.title);
    if (!name || !title) continue;
    const text = asString(v.text);
    const close_on_execute = typeof v.close_on_execute === 'boolean' ? v.close_on_execute : undefined;
    out.push({
      name,
      title,
      ...(text !== undefined ? { text } : {}),
      ...(close_on_execute !== undefined ? { close_on_execute } : {}),
    });
  }
  return out;
}

function tryParseItem(node: SerializedNode): PanelItem | null {
  if (node.type !== 'Box') return null;
  if ((node.children?.length ?? 0) > 0) return null;
  const title = asString(node.props.title);
  if (!title) return null;
  const subtitle = asString(node.props.subtitle) ?? '';
  const id = asString(node.props.id);
  return id ? { id, title, subtitle } : { title, subtitle };
}

function readDisplay(style: unknown): string | undefined {
  if (!isObject(style)) return;
  return asString(style.display);
}

function readFlexDir(style: unknown): 'vertical' | 'horizontal' | undefined {
  if (!isObject(style)) return;
  const dir = asString(style.flexDirection);
  if (dir === 'row') return 'horizontal';
  if (dir === 'column') return 'vertical';
  return;
}

function readGridColumns(style: unknown): number | undefined {
  if (!isObject(style)) return;
  return asFiniteNumber(style.gridColumns);
}

function readGridGap(style: unknown): number | undefined {
  if (!isObject(style)) return;
  return asFiniteNumber(style.gridColumnGap) ?? asFiniteNumber(style.gridRowGap) ?? asFiniteNumber(style.gap);
}

function readGap(props: Record<string, unknown>): number | undefined {
  return asFiniteNumber(props.gap) ?? readGridGap(props.style) ?? asFiniteNumber((props.style as any)?.gap);
}

function readDir(props: Record<string, unknown>): 'vertical' | 'horizontal' | undefined {
  const dir = asString(props.dir);
  if (dir === 'vertical' || dir === 'horizontal') return dir;
  return readFlexDir(props.style);
}

function readLayout(props: Record<string, unknown>): string | undefined {
  return asString(props.layout) ?? readDisplay(props.style);
}

function toPanelNode(node: SerializedNode): PanelNode | null {
  if (node.type !== 'Box') return null;

  const props = node.props ?? {};
  const children = node.children ?? [];

  const items: PanelItem[] = [];
  let allChildrenAreItems = children.length > 0;
  for (const c of children) {
    const it = tryParseItem(c);
    if (!it) {
      allChildrenAreItems = false;
      break;
    }
    items.push(it);
  }

  const layout = readLayout(props);
  const isGrid = layout === 'grid';

  if (allChildrenAreItems) {
    if (isGrid) {
      const columns = asFiniteNumber(props.columns) ?? readGridColumns(props.style);
      const gap = asFiniteNumber(props.gap) ?? readGridGap(props.style);
      return {
        type: 'grid',
        ...(columns !== undefined ? { columns } : {}),
        ...(gap !== undefined ? { gap } : {}),
        items,
      };
    }
    return { type: 'flex', items };
  }

  const outChildren: PanelNode[] = [];
  let pending: PanelItem[] = [];
  const flush = (): void => {
    if (pending.length === 0) return;
    outChildren.push({ type: 'flex', items: pending });
    pending = [];
  };

  for (const c of children) {
    const it = tryParseItem(c);
    if (it) {
      pending.push(it);
      continue;
    }
    flush();
    const childNode = toPanelNode(c);
    if (childNode) outChildren.push(childNode);
  }
  flush();

  const dir = readDir(props);
  const gap = readGap(props);
  return {
    type: 'box',
    ...(dir !== undefined ? { dir } : {}),
    ...(gap !== undefined ? { gap } : {}),
    children: outChildren,
  };
}

export type RenderedPanel = {
  panel: PanelData;
  actions?: ActionItem[];
};

export function panelFromSerializedRoot(
  root: SerializedNode | null,
  defaults?: { title?: string; subtitle?: string }
): RenderedPanel {
  const fallbackTop: PanelTop = {
    type: 'header',
    title: defaults?.title ?? '',
    ...(defaults?.subtitle ? { subtitle: defaults.subtitle } : {}),
  };

  if (!root) {
    return {
      panel: {
        top: fallbackTop,
        main: { type: 'flex', items: [] },
        bottom: { type: 'none' },
      },
    };
  }

  const top = parsePanelTop(root.props.top) ??
    (asString(root.props.title) ? {
      type: 'header',
      title: asString(root.props.title) ?? '',
      ...(asString(root.props.subtitle) ? { subtitle: asString(root.props.subtitle) } : {}),
    } : fallbackTop);

  const bottom = parsePanelBottom(root.props.bottom) ??
    (asString(root.props.bottomInfo) ? { type: 'info', text: asString(root.props.bottomInfo) ?? '' } : { type: 'none' });

  const actions = parseActions(root.props.actions);

  const main = toPanelNode(root) ?? { type: 'flex', items: [] };

  return {
    panel: { top, main, bottom },
    ...(actions && actions.length ? { actions } : {}),
  };
}

export async function panelFromReactNode(
  element: ReactNode,
  defaults?: { title?: string; subtitle?: string }
): Promise<RenderedPanel> {
  const payload = await renderOnce(element);
  return panelFromSerializedRoot(payload.root, defaults);
}
