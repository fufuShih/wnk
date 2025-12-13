import { handleHostEvent, type HostEvent } from './lib';
import { getResults } from './plugins/calculator/src/index';
import { getResults as getFileResults } from './plugins/files/src/index';

declare const process: any;

type ResultItem = { id?: string; title: string; subtitle?: string; icon?: string };

function writeJson(obj: object): void {
  console.log(JSON.stringify(obj));
}

function setupStdinListener(): void {
  if (!process?.stdin) return;

  process.stdin.setEncoding('utf8');
  let buffer = '';

  process.stdin.on('data', async (chunk: string) => {
    buffer += chunk;
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';

    for (const line of lines) {
      if (!line.trim()) continue;

      let msg: any;
      try { msg = JSON.parse(line); } catch { continue; }

      if (msg.type === 'query') {
        const text = msg.text ?? '';
        const calc: ResultItem[] = getResults(text);
        const files: ResultItem[] = await getFileResults(text);
        writeJson({ type: 'results', items: [...files, ...calc] });
      } else if (msg.type === 'command') {
        if (msg.name === 'setSearchText') {
          writeJson({ type: 'effect', name: 'setSearchText', text: msg.text ?? '' });
        }
      } else {
        try { handleHostEvent(msg as HostEvent); } catch {}
      }
    }
  });

  process.stdin.on('end', () => process.exit(0));
}

setupStdinListener();
