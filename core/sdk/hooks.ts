// ============================================
// Wink SDK Hooks
// React hooks for plugin development
// ============================================

import { useEffect, useCallback, useRef } from 'react';

// Global event emitter for host events
type EventHandler = (payload: unknown) => void;
const eventHandlers = new Map<string, Set<EventHandler>>();

// Register handler internally
export function _registerHandler(eventType: string, handler: EventHandler): () => void {
  if (!eventHandlers.has(eventType)) {
    eventHandlers.set(eventType, new Set());
  }
  eventHandlers.get(eventType)!.add(handler);

  return () => {
    eventHandlers.get(eventType)?.delete(handler);
  };
}

// Dispatch event from host
export function _dispatchHostEvent(eventType: string, payload: unknown): void {
  eventHandlers.get(eventType)?.forEach(handler => handler(payload));
}

// Hook: Listen for keyboard input
export function useInput(
  handler: (input: string, key: KeyInfo) => void,
  deps: React.DependencyList = []
): void {
  const handlerRef = useRef(handler);
  handlerRef.current = handler;

  useEffect(() => {
    const cleanup = _registerHandler('keydown', (payload) => {
      const { input, key } = payload as { input: string; key: KeyInfo };
      handlerRef.current(input, key);
    });
    return cleanup;
  }, deps);
}

export interface KeyInfo {
  name: string;
  ctrl: boolean;
  alt: boolean;
  shift: boolean;
  meta: boolean;
}

// Hook: Focus management
export function useFocus(): {
  isFocused: boolean;
  focus: () => void;
} {
  // Simplified focus - in real implementation would track focus state
  return {
    isFocused: false,
    focus: () => {},
  };
}

// Hook: Debounced callback
export function useDebounce<T extends (...args: unknown[]) => unknown>(
  callback: T,
  delay: number
): T {
  const timeoutRef = useRef<ReturnType<typeof setTimeout>>();

  return useCallback(
    ((...args: unknown[]) => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      timeoutRef.current = setTimeout(() => {
        callback(...args);
      }, delay);
    }) as T,
    [callback, delay]
  );
}

// Hook: Interval
export function useInterval(callback: () => void, delay: number | null): void {
  const savedCallback = useRef(callback);

  useEffect(() => {
    savedCallback.current = callback;
  }, [callback]);

  useEffect(() => {
    if (delay === null) return;

    const id = setInterval(() => savedCallback.current(), delay);
    return () => clearInterval(id);
  }, [delay]);
}
