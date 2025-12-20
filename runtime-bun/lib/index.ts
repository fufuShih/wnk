import type { ReactNode } from 'react';
import { wnkReconciler, setTreeUpdateCallback } from './reconciler';
import { wnkRoot } from './host-tree';
import type { RenderPayload, HostEvent } from '../sdk/types';
import { _dispatchHostEvent } from '../sdk/hooks';

let root: ReturnType<typeof wnkReconciler.createContainer> | null = null;
let rootInstance: wnkRoot | null = null;

type OutputMode = 'stdout' | 'callback';
let outputMode: OutputMode = 'stdout';
let outputCallback: ((payload: RenderPayload) => void) | null = null;

export function setOutputMode(mode: OutputMode, callback?: (payload: RenderPayload) => void): void {
  outputMode = mode;
  outputCallback = callback ?? null;
}

function emitToHost(r: wnkRoot): void {
  const payload: RenderPayload = { version: 1, root: r.serialize() };
  if (outputMode === 'stdout') console.log(JSON.stringify(payload));
  else outputCallback?.(payload);
}

export function render(element: ReactNode): void {
  if (!root) {
    rootInstance = new wnkRoot();
    setTreeUpdateCallback(emitToHost);
    root = wnkReconciler.createContainer(
      rootInstance, 0, null, false, null, '',
      (e: Error) => console.error('Recoverable error:', e), null
    );
  }
  wnkReconciler.updateContainer(element, root, null, () => {});
}

export function handleHostEvent(event: HostEvent): void {
  if (!rootInstance) return;
  switch (event.type) {
    case 'press': rootInstance.dispatchEvent(event.targetId, 'onPress'); break;
    case 'change': rootInstance.dispatchEvent(event.targetId, 'onChange', event.payload); break;
    case 'keydown': _dispatchHostEvent('keydown', event.payload); break;
  }
}

export function unmount(): void {
  if (root && rootInstance) {
    wnkReconciler.updateContainer(null, root, null, () => {});
    root = null;
    rootInstance = null;
  }
}

export type { RenderPayload, HostEvent };
