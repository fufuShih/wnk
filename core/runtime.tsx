import { handleHostEvent, type HostEvent } from './lib';
import { getResults as getCalcResults } from './plugins/calculator/dist/bundle.js';
import { getResults as getWeatherResults, getSubpanel as getWeatherSubpanel } from './plugins/weather/dist/bundle.js';

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
        const calc: ResultItem[] = getCalcResults(text);
        const weather: ResultItem[] = await getWeatherResults(text);
        writeJson({ type: 'results', items: [...weather, ...calc] });
      } else if (msg.type === 'getSubpanel') {
        const itemId = msg.itemId ?? '';
        // Try weather subpanel
        const subpanel = await getWeatherSubpanel(itemId);
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
