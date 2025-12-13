// ============================================
// wnk Renderer - Main Export
// Provides render() function for plugins
// ============================================

import type { ReactNode } from 'react';
import { wnkReconciler, setTreeUpdateCallback } from './reconciler';
import { wnkRoot } from './host-tree';
import type { RenderPayload, HostEvent } from '../sdk/types';
import { _dispatchHostEvent } from '../sdk/hooks';

// Global root instance
let root: ReturnType<typeof wnkReconciler.createContainer> | null = null;
let wnkRoot: wnkRoot | null = null;

// Output mode: 'stdout' for IPC with Zig host, 'callback' for testing
type OutputMode = 'stdout' | 'callback';
let outputMode: OutputMode = 'stdout';
let outputCallback: ((payload: RenderPayload) => void) | null = null;

// Set output mode (for testing)
export function setOutputMode(mode: OutputMode, callback?: (payload: RenderPayload) => void): void {
  outputMode = mode;
  outputCallback = callback ?? null;
}

// Emit UI tree to host
function emitToHost(root: wnkRoot): void {
  const payload: RenderPayload = {
    version: 1,
    root: root.serialize(),
  };

  if (outputMode === 'stdout') {
    // Output as single-line JSON to stdout for Zig to parse
    console.log(JSON.stringify(payload));
  } else if (outputCallback) {
    outputCallback(payload);
  }
}

// Render a React element
export function render(element: ReactNode): void {
  if (!root) {
    wnkRoot = new wnkRoot();

    // Set up tree update callback
    setTreeUpdateCallback(emitToHost);

    // Create React container
    root = wnkReconciler.createContainer(
      wnkRoot,
      0, // ConcurrentRoot = 1, LegacyRoot = 0
      null, // hydrationCallbacks
      false, // isStrictMode
      null, // concurrentUpdatesByDefaultOverride
      '', // identifierPrefix
      (error: Error) => console.error('Recoverable error:', error),
      null // transitionCallbacks
    );
  }

  // Update the container with new element
  wnkReconciler.updateContainer(element, root, null, () => {});
}

// Handle events from host (Zig)
export function handleHostEvent(event: HostEvent): void {
  if (!wnkRoot) return;

  switch (event.type) {
    case 'press':
      wnkRoot.dispatchEvent(event.targetId, 'onPress');
      break;
    case 'change':
      wnkRoot.dispatchEvent(event.targetId, 'onChange', event.payload);
      break;
    case 'keydown':
      _dispatchHostEvent('keydown', event.payload);
      break;
  }
}

// Clean up
export function unmount(): void {
  if (root && wnkRoot) {
    wnkReconciler.updateContainer(null, root, null, () => {});
    root = null;
    wnkRoot = null;
  }
}

// Re-export types
export type { RenderPayload, HostEvent };
