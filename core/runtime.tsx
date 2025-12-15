import { handleHostEvent, type HostEvent } from './lib';
import { getResults as getCalcResults } from './plugins/calculator/dist/bundle.js';
import { getResults as getWeatherResults, getSubpanel as getWeatherSubpanel } from './plugins/weather/dist/bundle.js';

declare const process: any;

type ResultItem = { id?: string; title: string; subtitle?: string; icon?: string };

function writeJson(obj: object): void {
  console.log(JSON.stringify(obj));
}

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

        const calc: ResultItem[] = getCalcResults(text);
        writeJson({ type: 'results', items: [...calc] });

        void (async () => {
          try {
            const weather: ResultItem[] = await getWeatherResults(text);
            if (token !== latestQueryToken) return;
            writeJson({ type: 'results', items: [...calc, ...weather] });
          } catch {}
        })();
      } else if (msg.type === 'getSubpanel') {
        const token = ++latestSubpanelToken;
        const itemId = msg.itemId ?? '';

        void (async () => {
          try {
            const subpanel = await getWeatherSubpanel(itemId);
            if (token !== latestSubpanelToken) return;

            if (subpanel) {
              writeJson({ type: 'subpanel', ...subpanel });
            } else {
              writeJson({
                type: 'subpanel',
                top: { type: 'header', title: itemId },
                main: { type: 'list', items: [] },
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
