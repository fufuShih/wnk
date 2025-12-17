import { handleHostEvent, type HostEvent } from './lib';
import { existsSync, readdirSync, readFileSync } from 'node:fs';

declare const process: any;

type PluginManifest = {
  id: string;
  name: string;
  icon?: string;
  entry?: string;
};

type PluginResultItem = { id?: string; title: string; subtitle?: string; icon?: string };
type ResultItem = { pluginId: string; id?: string; title: string; subtitle?: string; icon?: string };

type SubpanelItem = { title: string; subtitle: string };

type PanelTop = { type: 'header'; title: string; subtitle?: string } | { type: 'selected' };
type PanelBottom = { type: 'none' } | { type: 'info'; text: string };

type PanelNode =
  | { type: 'flex'; items: SubpanelItem[] }
  | { type: 'grid'; columns?: number; gap?: number; items: SubpanelItem[] }
  | { type: 'box'; dir?: 'vertical' | 'horizontal'; gap?: number; children: PanelNode[] };

type SubpanelData = { top: PanelTop; main: PanelNode; bottom?: PanelBottom };

type PluginModule = {
  getResults: (query: string) => PluginResultItem[] | Promise<PluginResultItem[]>;
  getSubpanel?: (itemId: string) => SubpanelData | null | Promise<SubpanelData | null>;
};

type LoadedPlugin = { manifest: PluginManifest; mod: PluginModule };

function writeJson(obj: object): void {
  console.log(JSON.stringify(obj));
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

    try {
      const modAny: any = await import(entryUrl.href);
      if (typeof modAny?.getResults !== 'function') continue;
      loaded.push({ manifest, mod: modAny as PluginModule });
    } catch {
      continue;
    }
  }

  // Stable order for rendering results.
  loaded.sort((a, b) => a.manifest.id.localeCompare(b.manifest.id));
  return loaded;
}

const plugins: LoadedPlugin[] = await loadPlugins();

let latestQueryToken = 0;
let latestSubpanelToken = 0;

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

            if (subpanel) {
              writeJson({ type: 'subpanel', pluginId, ...subpanel });
            } else {
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
        if (msg.name === 'setSearchText') {
          writeJson({ type: 'effect', name: 'setSearchText', text: msg.text ?? '' });
        }
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
