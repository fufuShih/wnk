// ============================================
// Calculator Plugin (results provider)
// Host supplies the input via query; we return list items.
// ============================================

import type { HostContext } from '@wnk/sdk';

export type ResultItem = { title: string; subtitle?: string; icon?: string };

type Token =
  | { kind: 'num'; value: number }
  | { kind: 'op'; value: '+' | '-' | '*' | '/' }
  | { kind: 'lparen' }
  | { kind: 'rparen' };

function tokenize(input: string): Token[] | null {
  const s = input.replace(/\s+/g, '');
  if (!s) return [];

  const tokens: Token[] = [];
  let i = 0;
  while (i < s.length) {
    const ch = s[i];

    if (ch === '(') {
      tokens.push({ kind: 'lparen' });
      i += 1;
      continue;
    }
    if (ch === ')') {
      tokens.push({ kind: 'rparen' });
      i += 1;
      continue;
    }
    if (ch === '+' || ch === '*' || ch === '/') {
      tokens.push({ kind: 'op', value: ch });
      i += 1;
      continue;
    }

    // unary minus: treat as part of number if at start or after operator/(
    if (ch === '-') {
      const prev = tokens[tokens.length - 1];
      const isUnary = !prev || prev.kind === 'op' || prev.kind === 'lparen';
      if (!isUnary) {
        tokens.push({ kind: 'op', value: '-' });
        i += 1;
        continue;
      }
    }

    // number
    const m = s.slice(i).match(/^-?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?/i);
    if (!m) return null;
    const n = Number(m[0]);
    if (!Number.isFinite(n)) return null;
    tokens.push({ kind: 'num', value: n });
    i += m[0].length;
  }
  return tokens;
}

function precedence(op: '+' | '-' | '*' | '/'): number {
  return op === '*' || op === '/' ? 2 : 1;
}

function toRpn(tokens: Token[]): Token[] | null {
  const output: Token[] = [];
  const stack: Token[] = [];

  for (const t of tokens) {
    if (t.kind === 'num') {
      output.push(t);
      continue;
    }
    if (t.kind === 'op') {
      while (stack.length) {
        const top = stack[stack.length - 1];
        if (top.kind === 'op' && precedence(top.value) >= precedence(t.value)) {
          output.push(stack.pop()!);
        } else {
          break;
        }
      }
      stack.push(t);
      continue;
    }
    if (t.kind === 'lparen') {
      stack.push(t);
      continue;
    }
    if (t.kind === 'rparen') {
      let found = false;
      while (stack.length) {
        const top = stack.pop()!;
        if (top.kind === 'lparen') {
          found = true;
          break;
        }
        output.push(top);
      }
      if (!found) return null;
      continue;
    }
  }

  while (stack.length) {
    const top = stack.pop()!;
    if (top.kind === 'lparen' || top.kind === 'rparen') return null;
    output.push(top);
  }
  return output;
}

function evalRpn(tokens: Token[]): number | null {
  const stack: number[] = [];
  for (const t of tokens) {
    if (t.kind === 'num') {
      stack.push(t.value);
      continue;
    }
    if (t.kind === 'op') {
      const b = stack.pop();
      const a = stack.pop();
      if (a === undefined || b === undefined) return null;
      let r: number;
      switch (t.value) {
        case '+':
          r = a + b;
          break;
        case '-':
          r = a - b;
          break;
        case '*':
          r = a * b;
          break;
        case '/':
          if (b === 0) return null;
          r = a / b;
          break;
      }
      if (!Number.isFinite(r)) return null;
      stack.push(r);
    }
  }
  return stack.length === 1 ? stack[0] : null;
}

function tryEvaluate(expr: string): number | null {
  const tokens = tokenize(expr);
  if (!tokens) return null;
  if (tokens.length === 0) return null;
  const rpn = toRpn(tokens);
  if (!rpn) return null;
  return evalRpn(rpn);
}

export function getResults(query: string, ctx?: HostContext): ResultItem[] {
  const trimmed = query.trim();
  const selection = ctx?.selectionText?.trim() ?? '';
  const input = trimmed.length > 0 ? trimmed : selection;
  if (!input) return [];

  const value = tryEvaluate(input);
  if (value === null) return [];

  const title = String(value);
  const subtitle = `${input} = ${title}`;
  return [{ title, subtitle, icon: '=' }];
}

// Default export kept for compatibility (unused in list-mode).
export default function CalculatorPlugin(): null {
  return null;
}
