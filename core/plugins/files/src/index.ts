// ============================================
// Files Plugin (results provider)
// Trigger: "file <term>" or "f <term>"
// Returns matching files under configured roots.
// ============================================

import * as path from 'path';
import { readdir, stat } from 'fs/promises';
import type { Dirent, Stats } from 'fs';

export type ResultItem = { id?: string; title: string; subtitle?: string; icon?: string };

const DEFAULT_IGNORED_DIRS = new Set([
  '.git',
  'node_modules',
  '.zig-cache',
  'zig-out',
  'dist',
  'build',
  '.idea',
  '.vscode',
]);

function normalizeTerm(s: string): string {
  return s.trim().toLowerCase();
}

function parseFileQuery(query: string): string | null {
  const trimmed = query.trim();
  if (trimmed.length === 0) return null;

  if (trimmed.toLowerCase().startsWith('file ')) return trimmed.slice(5).trim();
  if (trimmed.toLowerCase().startsWith('f ')) return trimmed.slice(2).trim();
  return null;
}

async function statSafe(p: string): Promise<Stats | null> {
  try {
    return await stat(p);
  } catch {
    return null;
  }
}

function splitRoots(envValue: string | undefined): string[] {
  if (!envValue) return [];
  return envValue
    .split(';')
    .map(s => s.trim())
    .filter(Boolean);
}

async function defaultRoots(): Promise<string[]> {
  const roots: string[] = [];

  const envRoots = splitRoots(process.env.WNK_FILE_ROOTS);
  for (const r of envRoots) {
    const st = await statSafe(r);
    if (st?.isDirectory()) roots.push(r);
  }
  if (roots.length) return roots;

  const userProfile = process.env.USERPROFILE;
  if (userProfile) {
    for (const sub of ['Desktop', 'Documents', 'Downloads']) {
      const p = path.join(userProfile, sub);
      const st = await statSafe(p);
      if (st?.isDirectory()) roots.push(p);
    }
  }

  // Keep a sane default if workspace exists.
  const workspace = 'C:\\workspace';
  const wst = await statSafe(workspace);
  if (wst?.isDirectory()) roots.push(workspace);

  return roots;
}

type QueueItem = { dir: string; depth: number };

async function searchRoots(roots: string[], term: string): Promise<ResultItem[]> {
  const results: ResultItem[] = [];
  const maxResults = 30;
  const maxDirsVisited = 2500;
  const maxDepth = 6;

  // BFS directory walk
  const queue: QueueItem[] = roots.map(r => ({ dir: r, depth: 0 }));
  let visitedDirs = 0;

  while (queue.length > 0) {
    const { dir, depth } = queue.shift()!;
    if (depth > maxDepth) continue;
    if (visitedDirs++ > maxDirsVisited) break;

    let entries: Dirent[];
    try {
      entries = await readdir(dir, { withFileTypes: true });
    } catch {
      continue;
    }

    for (const ent of entries) {
      const name = ent.name;
      if (ent.isDirectory()) {
        if (DEFAULT_IGNORED_DIRS.has(name)) continue;
        queue.push({ dir: path.join(dir, name), depth: depth + 1 });
        continue;
      }

      if (!ent.isFile()) continue;

      if (name.toLowerCase().includes(term)) {
        const fullPath = path.join(dir, name);
        results.push({
          id: `file:${fullPath}`,
          title: name,
          subtitle: fullPath,
          icon: 'F',
        });
        if (results.length >= maxResults) return results;
      }
    }
  }

  return results;
}

export async function getResults(query: string): Promise<ResultItem[]> {
  const termRaw = parseFileQuery(query);
  if (termRaw == null) return [];

  const term = normalizeTerm(termRaw);
  if (!term) return [];

  const roots = await defaultRoots();
  if (roots.length === 0) return [];

  return searchRoots(roots, term);
}
