import type { HostContext, PanelData, ResultItem } from '@wnk/sdk';

function countWords(text: string): number {
  const trimmed = text.trim();
  if (!trimmed) return 0;
  const matches = trimmed.match(/[\p{L}\p{N}]+(?:['_-][\p{L}\p{N}]+)*/gu);
  return matches ? matches.length : 0;
}

function countLines(text: string): number {
  if (!text) return 0;
  return text.split(/\r\n|\r|\n/).length;
}

function truncatePreview(text: string, maxLen: number): string {
  if (text.length <= maxLen) return text;
  return text.slice(0, maxLen - 3) + '...';
}

let lastSelection = '';
let lastSource: HostContext['selectionSource'] = undefined;
let lastWords = 0;
let lastChars = 0;
let lastLines = 0;

function updateSnapshot(selection: string, source?: HostContext['selectionSource']): void {
  lastSelection = selection;
  lastSource = source;
  lastWords = countWords(selection);
  lastChars = selection.length;
  lastLines = countLines(selection);
}

export function getResults(query: string, ctx?: HostContext): ResultItem[] {
  const selection = ctx?.selectionText ?? '';
  if (!selection.trim()) {
    lastSelection = '';
    lastSource = ctx?.selectionSource;
    lastWords = 0;
    lastChars = 0;
    lastLines = 0;
    if (query.trim().length > 0) return [];
    return [
      {
        id: 'selection',
        title: 'Word Count',
        subtitle: 'No selection',
        icon: 'WC',
        contextual: true,
      },
    ];
  }

  updateSnapshot(selection, ctx?.selectionSource);

  return [
    {
      id: 'selection',
      title: `Words: ${lastWords}`,
      subtitle: `Chars: ${lastChars}`,
      icon: 'WC',
      contextual: true,
    },
  ];
}

export function getPanel(_itemId: string): PanelData | null {
  if (!lastSelection.trim()) {
    return {
      top: { type: 'header', title: 'Word Count', subtitle: 'No selection' },
      main: {
        type: 'box',
        items: [
          {
            title: 'Select text in another app',
            subtitle: 'Press Alt+Space to refresh',
          },
        ],
      },
      bottom: { type: 'info', text: 'Alt+Space to refresh selection' },
    };
  }

  const preview = truncatePreview(lastSelection.replace(/\s+/g, ' ').trim(), 160);
  const sourceLabel = lastSource ? `Source: ${lastSource}` : 'Source: unknown';

  return {
    top: { type: 'header', title: 'Word Count', subtitle: sourceLabel },
    main: {
      type: 'box',
      dir: 'vertical',
      gap: 12,
      children: [
        {
          type: 'box',
          items: [
            {
              title: 'Selection',
              subtitle: preview,
            },
          ],
        },
        {
          type: 'box',
          layout: 'grid',
          columns: 3,
          gap: 12,
          items: [
            { title: String(lastWords), subtitle: 'Words' },
            { title: String(lastChars), subtitle: 'Chars' },
            { title: String(lastLines), subtitle: 'Lines' },
          ],
        },
      ],
    },
    bottom: { type: 'info', text: 'Enter: open  Esc: back  Alt+Space: refresh' },
  };
}

export default function WordCountPlugin(): null {
  return null;
}
