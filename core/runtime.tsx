// ============================================
// wnk Core - Entry Point
// Simplified: query -> results (calculator provider)
// ============================================

import { handleHostEvent, type HostEvent } from './lib';
import { getResults } from './plugins/calculator/src/index';
import { getResults as getFileResults } from './plugins/files/src/index';

// Bun provides `process` at runtime; keep TS simple without adding @types/node.
declare const process: any;

type QueryMessage = { type: 'query'; text: string };
type CommandMessage = { type: 'command'; name: string; text?: string };
type AnyMessage = QueryMessage | CommandMessage | HostEvent | { type?: string; [k: string]: unknown };

type ResultItem = { id?: string; title: string; subtitle?: string; icon?: string };

function safeJsonParse(line: string): AnyMessage | null {
  try {
    return JSON.parse(line) as AnyMessage;
  } catch {
    return null;
  }
}

function writeResults(items: ResultItem[]): void {
  // Zig reads a single JSON object per line.
  console.log(JSON.stringify({ type: 'results', items }));
}

function writeEffect(effect: { name: string; text?: string }): void {
  console.log(JSON.stringify({ type: 'effect', ...effect }));
}

// Listen for events from stdin (from Zig host)
function setupStdinListener(): void {
  if (typeof process !== 'undefined' && process.stdin) {
    process.stdin.setEncoding('utf8');

    let buffer = '';

    process.stdin.on('data', async (chunk: string) => {
      buffer += chunk;

      // Process complete JSON lines
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (line.trim()) {
          const msg = safeJsonParse(line);
          if (!msg) continue;

          if ((msg as any).type === 'query') {
            const text = typeof (msg as any).text === 'string' ? (msg as any).text : '';
            const calc: ResultItem[] = getResults(text);
            const files: ResultItem[] = await getFileResults(text);
            writeResults([...files, ...calc]);
            continue;
          }

          if ((msg as any).type === 'command') {
            const m = msg as CommandMessage;
            const name = typeof (m as any).name === 'string' ? (m as any).name : '';
            const text = typeof (m as any).text === 'string' ? (m as any).text : '';

            if (name === 'setSearchText') {
              writeEffect({ name: 'setSearchText', text });
            }

            continue;
          }

          // Back-compat: still allow host events.
          try {
            handleHostEvent(msg as HostEvent);
          } catch {
            // Ignore malformed/non-event messages.
          }
        }
      }
    });

    process.stdin.on('end', () => {
      process.exit(0);
    });
  }
}

// Main entry point
async function main(): Promise<void> {
  // Setup stdin listener for host events
  setupStdinListener();

  // Keep process alive (stdin listener)
}

// Run
main().catch(console.error);
