import { useEffect, useCallback, useRef } from 'react';

type EventHandler = (payload: unknown) => void;
const eventHandlers = new Map<string, Set<EventHandler>>();

export function _registerHandler(type: string, handler: EventHandler): () => void {
  if (!eventHandlers.has(type)) eventHandlers.set(type, new Set());
  eventHandlers.get(type)!.add(handler);
  return () => { eventHandlers.get(type)?.delete(handler); };
}

export function _dispatchHostEvent(type: string, payload: unknown): void {
  eventHandlers.get(type)?.forEach(h => h(payload));
}

export interface KeyInfo { name: string; ctrl: boolean; alt: boolean; shift: boolean; meta: boolean; }

export function useInput(handler: (input: string, key: KeyInfo) => void, deps: React.DependencyList = []): void {
  const ref = useRef(handler);
  ref.current = handler;
  useEffect(() => _registerHandler('keydown', (p) => {
    const { input, key } = p as { input: string; key: KeyInfo };
    ref.current(input, key);
  }), deps);
}

export function useFocus(): { isFocused: boolean; focus: () => void } {
  return { isFocused: false, focus: () => {} };
}

export function useDebounce<T extends (...args: unknown[]) => unknown>(cb: T, delay: number): T {
  const timeout = useRef<ReturnType<typeof setTimeout>>();
  return useCallback(((...args: unknown[]) => {
    if (timeout.current) clearTimeout(timeout.current);
    timeout.current = setTimeout(() => cb(...args), delay);
  }) as T, [cb, delay]);
}

export function useInterval(cb: () => void, delay: number | null): void {
  const saved = useRef(cb);
  useEffect(() => { saved.current = cb; }, [cb]);
  useEffect(() => {
    if (delay === null) return;
    const id = setInterval(() => saved.current(), delay);
    return () => clearInterval(id);
  }, [delay]);
}
