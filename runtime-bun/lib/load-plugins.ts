import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { type ReactNode } from 'react';
import type { ActionItem, HostContext, PanelData, ResultItem as PluginResultItem } from '../sdk/ipc';

type PluginManifest = {
  id: string;
  name: string;
  icon?: string;
  entry?: string;
};

type PluginModule = {
  getResults: (query: string, ctx?: HostContext) => PluginResultItem[] | Promise<PluginResultItem[]>;
  getPanel?: (itemId: string) => PanelData | ReactNode | null | Promise<PanelData | ReactNode | null>;
  getActions?: (ctx: {
    panel: 'search' | 'details';
    pluginId: string;
    itemId: string;
    selectedId?: string;
    selectedText?: string;
    query?: string;
    hostContext?: HostContext;
  }) => ActionItem[] | Promise<ActionItem[]>;
  onCommand?: (name: string, text: string) => PanelData | ReactNode | null | void | Promise<PanelData | ReactNode | null | void>;
};

export type LoadedPlugin = { manifest: PluginManifest; mod: PluginModule };

export async function loadPlugins(): Promise<LoadedPlugin[]> {
  const pluginsDir = new URL('../plugins/', import.meta.url);
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
