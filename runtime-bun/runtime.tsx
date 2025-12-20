import { handleHostEvent, type HostEvent } from './lib';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { createElement, Fragment, isValidElement, type ReactNode } from 'react';
import type { ActionItem, PanelData, ResultItem as PluginResultItem } from './sdk/ipc';
import type { RenderPayload, SerializedNode } from './sdk/types';
import { panelFromReactNode, panelFromSerializedRoot, type RenderedPanel } from './lib/panel';
import { loadPlugins, type LoadedPlugin } from './lib/load-plugins';

declare const process: any;

type ResultItem = { pluginId: string; id?: string; title: string; subtitle?: string; icon?: string };


function writeJson(obj: object): void {
  console.log(JSON.stringify(obj));
}

function isPanelData(value: unknown): value is PanelData {
  return typeof value === 'object' && value !== null && !Array.isArray(value) && 'top' in value && 'main' in value;
}

function isSerializedNode(value: unknown): value is SerializedNode {
  return typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    typeof (value as any).type === 'string' &&
    (value as any).props !== null &&
    typeof (value as any).props === 'object' &&
    Array.isArray((value as any).children);
}

function isRenderPayload(value: unknown): value is RenderPayload {
  return typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    (value as any).version === 1 &&
    'root' in (value as any);
}

function normalizePanelReactNode(node: ReactNode): ReactNode {
  if (Array.isArray(node)) return createElement('wnk-box', null, node);
  if (isValidElement(node) && node.type === Fragment) return createElement('wnk-box', null, node);
  return node;
}

async function renderPanelOutput(
  output: unknown,
  defaults?: { title?: string; subtitle?: string }
): Promise<RenderedPanel | null> {
  if (output === null || output === undefined) return null;
  if (isPanelData(output)) return { panel: output };
  if (isRenderPayload(output)) return panelFromSerializedRoot(output.root, defaults);
  if (isSerializedNode(output)) return panelFromSerializedRoot(output, defaults);

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

  return await panelFromReactNode(normalizePanelReactNode(node), defaults);
}


const plugins: LoadedPlugin[] = await loadPlugins();

let latestQueryToken = 0;
let latestPanelToken = 0;
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
      } else if (msg.type === 'getPanel') {
        const token = ++latestPanelToken;
        const pluginId = msg.pluginId ?? '';
        const itemId = msg.itemId ?? '';
        if (pluginId && itemId) lastDetailsItemByPlugin.set(pluginId, itemId);

        const plugin = plugins.find((p) => p.manifest.id === pluginId);
        if (!plugin || typeof plugin.mod.getPanel !== 'function') {
          writeJson({
            type: 'panel',
            pluginId,
            top: { type: 'header', title: itemId },
            main: { type: 'flex', items: [] },
            bottom: { type: 'none' },
          });
          continue;
        }

        void (async () => {
          try {
            const panel = await plugin.mod.getPanel?.(itemId);
            if (token !== latestPanelToken) return;

            const rendered = await renderPanelOutput(panel, { title: itemId });
            if (token !== latestPanelToken) return;

            if (rendered) {
              if (rendered.actions) actionsCache.set(`${pluginId}:${itemId}`, rendered.actions);
              else actionsCache.delete(`${pluginId}:${itemId}`);
              writeJson({ type: 'panel', pluginId, ...rendered.panel });
            } else {
              actionsCache.delete(`${pluginId}:${itemId}`);
              writeJson({
                type: 'panel',
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
            const panel = await plugin.mod.onCommand?.(commandName, text);
            if (!panel) return;

            const rendered = await renderPanelOutput(panel, { title: pluginId });
            if (rendered) {
              const itemId = lastDetailsItemByPlugin.get(pluginId);
              if (itemId) {
                if (rendered.actions) actionsCache.set(`${pluginId}:${itemId}`, rendered.actions);
                else actionsCache.delete(`${pluginId}:${itemId}`);
              }
              writeJson({ type: 'panel', pluginId, ...rendered.panel });
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

            if (panel === 'details' && typeof plugin.mod.getPanel === 'function') {
              const maybePanel = await plugin.mod.getPanel(itemId);
              const rendered = await renderPanelOutput(maybePanel, { title: itemId });
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
