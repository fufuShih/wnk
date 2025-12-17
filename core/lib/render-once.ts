import type { ReactNode } from 'react';
import type { RenderPayload } from '../sdk/types';
import { wnkRoot } from './host-tree';
import { wnkReconciler } from './reconciler';

export async function renderOnce(element: ReactNode): Promise<RenderPayload> {
  const rootInstance = new wnkRoot();
  const container = wnkReconciler.createContainer(
    rootInstance,
    0,
    null,
    false,
    null,
    '',
    (e: Error) => console.error('Recoverable error:', e),
    null
  );

  await new Promise<void>((resolve) => {
    wnkReconciler.updateContainer(element, container, null, () => resolve());
  });

  const payload: RenderPayload = { version: 1, root: rootInstance.serialize() };
  wnkReconciler.updateContainer(null, container, null, () => {});
  return payload;
}

