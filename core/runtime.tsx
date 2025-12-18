import { handleHostEvent, type HostEvent } from './lib';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { createElement, Fragment, isValidElement, type ReactNode } from 'react';
import type { ActionItem, ResultItem as PluginResultItem, SubpanelData } from './sdk/ipc';
import { subpanelFromReactNode, type RenderedSubpanel } from './lib/subpanel';

declare const process: any;

type PluginManifest = {
  id: string;
  name: string;
  icon?: string;
  entry?: string;
};

type ResultItem = { pluginId: string; id?: string; title: string; subtitle?: string; icon?: string };

type PluginModule = {
  getResults: (query: string) => PluginResultItem[] | Promise<PluginResultItem[]>;
  getSubpanel?: (itemId: string) => SubpanelData | ReactNode | null | Promise<SubpanelData | ReactNode | null>;
  getActions?: (ctx: {
    panel: 'search' | 'details';
    pluginId: string;
    itemId: string;
    selectedId?: string;
    selectedText?: string;
    query?: string;
  }) => ActionItem[] | Promise<ActionItem[]>;
  onCommand?: (name: string, text: string) => SubpanelData | ReactNode | null | void | Promise<SubpanelData | ReactNode | null | void>;
};

type LoadedPlugin = { manifest: PluginManifest; mod: PluginModule };

function writeJson(obj: object): void {
  console.log(JSON.stringify(obj));
}

function isSubpanelData(value: unknown): value is SubpanelData {
  return typeof value === 'object' && value !== null && !Array.isArray(value) && 'top' in value && 'main' in value;
}

function normalizeSubpanelReactNode(node: ReactNode): ReactNode {
  if (Array.isArray(node)) return createElement('wnk-box', null, node);
  if (isValidElement(node) && node.type === Fragment) return createElement('wnk-box', null, node);
  return node;
}

async function renderSubpanelOutput(
  output: unknown,
  defaults?: { title?: string; subtitle?: string }
): Promise<RenderedSubpanel | null> {
  if (output === null || output === undefined) return null;
  if (isSubpanelData(output)) return { subpanel: output };

  let node: ReactNode;
  if (typeof output === 'function') {
    node = createElement(output as any, null);
  } else if (
    isValidElement(output) ||
    Array.isArray(output) ||
    typeof output === 'string' ||
    typeof output === 'number' ||
    typeof output === 'boolean'
  ) {
    node = output as ReactNode;
  } else {
    return null;
  }

  return await subpanelFromReactNode(normalizeSubpanelReactNode(node), defaults);
}

async function loadPlugins(): Promise<LoadedPlugin[]> {
  const pluginsDir = new URL('./plugins/', import.meta.url);
  const dirs = readdirSync(pluginsDir, { withFileTypes: true }).filter((d) => d.isDirectory());

  const loaded: LoadedPlugin[] = [];
  for (const d of dirs) {
    const pluginBase = new URL(`${d.name}/`, pluginsDir);
    const manifestUrl = new URL('manifest.json', pluginBase);
    if (!existsSync(manifestUrl)) continue;

    let manifest: PluginManifest;
    try {
      manifest = JSON.parse(readFileSync(manifestUrl, 'utf8')) as PluginManifest;
    } catch {
      continue;
    }
    if (!manifest?.id) continue;

    const entry = manifest.entry ?? './dist/bundle.js';
    const entryUrl = new URL(entry, pluginBase);

    const tryImport = async (href: string): Promise<any | null> => {
      try {
        return await import(href);
      } catch (e: any) {
        return null;
      }
    };

    // Prefer bundled entry, but fall back to source during development.
    let modAny: any = await tryImport(entryUrl.href);
    if (!modAny) {
      modAny = await tryImport(new URL('./src/index.tsx', pluginBase).href);
      if (!modAny) modAny = await tryImport(new URL('./src/index.ts', pluginBase).href);
    }

    if (typeof modAny?.getResults !== 'function') continue;
    loaded.push({ manifest, mod: modAny as PluginModule });
  }

  // Stable order for rendering results.
  loaded.sort((a, b) => a.manifest.id.localeCompare(b.manifest.id));
  return loaded;
}

const plugins: LoadedPlugin[] = await loadPlugins();

let latestQueryToken = 0;
let latestSubpanelToken = 0;
const lastDetailsItemByPlugin = new Map<string, string>();
const actionsCache = new Map<string, ActionItem[]>();

let stdinBuffer = '';
const stdinQueue: string[] = [];
let draining = false;

async function drainStdinQueue(): Promise<void> {
  if (draining) return;
  draining = true;

  try {
    while (stdinQueue.length > 0) {
      const line = stdinQueue.shift()!;
      if (!line.trim()) continue;

      let msg: any;
      try { msg = JSON.parse(line); } catch { continue; }

      if (msg.type === 'query') {
        const token = ++latestQueryToken;
        const text = msg.text ?? '';
        const byPlugin = new Map<string, ResultItem[]>();

        const emit = (): void => {
          const combined: ResultItem[] = [];
          for (const p of plugins) {
            const items = byPlugin.get(p.manifest.id);
            if (items && items.length) combined.push(...items);
          }
          writeJson({ type: 'results', items: combined });
        };

        for (const p of plugins) {
          void (async () => {
            try {
              const itemsRaw = await p.mod.getResults(text);
              if (token !== latestQueryToken) return;

              const items: ResultItem[] = (itemsRaw ?? []).map((it) => ({
                pluginId: p.manifest.id,
                id: it.id,
                title: it.title,
                subtitle: it.subtitle,
                icon: it.icon ?? p.manifest.icon,
              }));

              byPlugin.set(p.manifest.id, items);
              emit();
            } catch {}
          })();
        }
      } else if (msg.type === 'getSubpanel') {
        const token = ++latestSubpanelToken;
        const pluginId = msg.pluginId ?? '';
        const itemId = msg.itemId ?? '';
        if (pluginId && itemId) lastDetailsItemByPlugin.set(pluginId, itemId);

        const plugin = plugins.find((p) => p.manifest.id === pluginId);
        if (!plugin || typeof plugin.mod.getSubpanel !== 'function') {
          writeJson({
            type: 'subpanel',
            pluginId,
            top: { type: 'header', title: itemId },
            main: { type: 'flex', items: [] },
            bottom: { type: 'none' },
          });
          continue;
        }

        void (async () => {
          try {
            const subpanel = await plugin.mod.getSubpanel?.(itemId);
            if (token !== latestSubpanelToken) return;

            const rendered = await renderSubpanelOutput(subpanel, { title: itemId });
              if (token !== latestSubpanelToken) return;

            if (rendered) {
              if (rendered.actions) actionsCache.set(`${pluginId}:${itemId}`, rendered.actions);
              else actionsCache.delete(`${pluginId}:${itemId}`);
              writeJson({ type: 'subpanel', pluginId, ...rendered.subpanel });
            } else {
              actionsCache.delete(`${pluginId}:${itemId}`);
              writeJson({
                type: 'subpanel',
                pluginId,
                top: { type: 'header', title: itemId },
                main: { type: 'flex', items: [] },
                bottom: { type: 'none' },
              });
            }
          } catch {}
        })();
      } else if (msg.type === 'command') {
        const name = msg.name ?? '';
        const text = msg.text ?? '';

        if (name === 'setSearchText') {
          writeJson({ type: 'effect', name: 'setSearchText', text: msg.text ?? '' });
          continue;
        }

        const dot = name.indexOf('.');
        if (dot <= 0) continue;

        const pluginId = name.slice(0, dot);
        const commandName = name.slice(dot + 1);

        const plugin = plugins.find((p) => p.manifest.id === pluginId);
        if (!plugin || typeof plugin.mod.onCommand !== 'function') continue;

        void (async () => {
          try {
            const subpanel = await plugin.mod.onCommand?.(commandName, text);
            if (!subpanel) return;

            const rendered = await renderSubpanelOutput(subpanel, { title: pluginId });
            if (rendered) {
              const itemId = lastDetailsItemByPlugin.get(pluginId);
              if (itemId) {
                if (rendered.actions) actionsCache.set(`${pluginId}:${itemId}`, rendered.actions);
                else actionsCache.delete(`${pluginId}:${itemId}`);
              }
              writeJson({ type: 'subpanel', pluginId, ...rendered.subpanel });
            }
          } catch {}
        })();
      } else if (msg.type === 'getActions') {
        const token = msg.token ?? 0;
        const panel = msg.panel === 'details' ? 'details' : 'search';
        const pluginId = msg.pluginId ?? '';
        const itemId = msg.itemId ?? '';
        const selectedId = msg.selectedId ?? '';
        const selectedText = msg.selectedText ?? '';
        const query = msg.query ?? '';

        const plugin = plugins.find((p) => p.manifest.id === pluginId);
        if (!plugin) {
          writeJson({ type: 'actions', token, pluginId, items: [] });
          continue;
        }

        void (async () => {
          try {
            if (typeof plugin.mod.getActions === 'function') {
              const items = await plugin.mod.getActions?.({
                panel,
                pluginId,
                itemId,
                selectedId: selectedId || undefined,
                selectedText: selectedText || undefined,
                query: query || undefined,
              });
              writeJson({ type: 'actions', token, pluginId, items: items ?? [] });
              return;
            }

            const cached = actionsCache.get(`${pluginId}:${itemId}`);
            if (cached) {
              writeJson({ type: 'actions', token, pluginId, items: cached });
              return;
            }

            if (panel === 'details' && typeof plugin.mod.getSubpanel === 'function') {
              const maybePanel = await plugin.mod.getSubpanel(itemId);
              const rendered = await renderSubpanelOutput(maybePanel, { title: itemId });
              if (rendered) {
                if (rendered.actions) actionsCache.set(`${pluginId}:${itemId}`, rendered.actions);
                writeJson({ type: 'actions', token, pluginId, items: rendered.actions ?? [] });
                return;
              }
            }

            writeJson({ type: 'actions', token, pluginId, items: [] });
          } catch {}
        })();
      } else {
        try { handleHostEvent(msg as HostEvent); } catch {}
      }
    }
  } finally {
    draining = false;
    if (stdinQueue.length > 0) void drainStdinQueue();
  }
}

function setupStdinListener(): void {
  if (!process?.stdin) return;

  process.stdin.setEncoding('utf8');

  process.stdin.on('data', (chunk: string) => {
    stdinBuffer += chunk;
    const lines = stdinBuffer.split('\n');
    stdinBuffer = lines.pop() || '';
    for (const line of lines) stdinQueue.push(line);
    void drainStdinQueue();
  });

  process.stdin.on('end', () => process.exit(0));
}

setupStdinListener();
