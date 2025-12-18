import ReactReconciler from 'react-reconciler';
import { DefaultEventPriority } from 'react-reconciler/constants';
import { wnkNode, wnkRoot, mapElementType } from './host-tree';

type Container = wnkRoot;
type Instance = wnkNode;
type Props = Record<string, unknown>;

let onTreeUpdate: ((root: wnkRoot) => void) | null = null;
export function setTreeUpdateCallback(cb: (root: wnkRoot) => void): void { onTreeUpdate = cb; }

function isTextChild(v: unknown): v is string | number {
  return typeof v === 'string' || typeof v === 'number';
}

const hostConfig: ReactReconciler.HostConfig<
  string, Props, Container, Instance, Instance, never, never, Instance,
  Record<string, never>, Props, never, ReturnType<typeof setTimeout>, -1
> = {
  createInstance(type: string, props: Props, root: Container): Instance {
    const node = new wnkNode(mapElementType(type), props);
    if (isTextChild(props.children)) node.text = String(props.children);
    if (typeof props.onPress === 'function') root.registerHandler(node.id, 'onPress', props.onPress as () => void);
    if (typeof props.onChange === 'function') root.registerHandler(node.id, 'onChange', props.onChange as (...a: unknown[]) => void);
    return node;
  },

  createTextInstance(text: string): Instance {
    const node = new wnkNode('Text', {});
    node.text = text;
    return node;
  },

  appendInitialChild: (p, c) => p.appendChild(c),
  appendChild: (p, c) => p.appendChild(c),
  appendChildToContainer: (c, child) => { c.appendChildToContainer(child); onTreeUpdate?.(c); },
  insertBefore: (p, c, before) => p.insertBefore(c, before),
  insertInContainerBefore: (c, child, before) => { c.insertChildInContainerBefore(child, before); onTreeUpdate?.(c); },
  removeChild: (p, c) => p.removeChild(c),
  removeChildFromContainer: (c, child) => { c.removeChildFromContainer(child); onTreeUpdate?.(c); },

  prepareUpdate(_i, _t, oldP: Props, newP: Props): Props | null {
    const payload: Props = {};
    let changed = false;
    for (const k of Object.keys(newP)) {
      if (k === 'children') {
        if ((isTextChild(oldP.children) || isTextChild(newP.children)) && oldP.children !== newP.children) {
          payload.children = newP.children; changed = true;
        }
      } else if (oldP[k] !== newP[k]) { payload[k] = newP[k]; changed = true; }
    }
    for (const k of Object.keys(oldP)) {
      if (k === 'children') continue;
      if (!(k in newP)) { payload[k] = undefined; changed = true; }
    }
    return changed ? payload : null;
  },

  commitUpdate(inst, _payload, _t, _prev, next: Props): void {
    inst.updateProps(_payload);
    inst.text = isTextChild(next.children) ? String(next.children) : null;
  },

  commitTextUpdate: (t, _o, n) => { t.text = n; },
  finalizeInitialChildren: () => false,
  prepareForCommit: () => null,
  resetAfterCommit: (c) => onTreeUpdate?.(c),
  getRootHostContext: () => ({}),
  getChildHostContext: () => ({}),
  getPublicInstance: (i) => i,
  shouldSetTextContent: (_t, p) => isTextChild(p.children),
  clearContainer: (c) => c.clearContainer(),

  supportsMutation: true,
  supportsPersistence: false,
  supportsHydration: false,
  isPrimaryRenderer: true,
  warnsIfNotActing: true,
  scheduleTimeout: setTimeout,
  cancelTimeout: clearTimeout,
  noTimeout: -1 as -1,
  getCurrentEventPriority: () => DefaultEventPriority,
  getInstanceFromNode: () => null,
  beforeActiveInstanceBlur: () => {},
  afterActiveInstanceBlur: () => {},
  prepareScopeUpdate: () => {},
  getInstanceFromScope: () => null,
  detachDeletedInstance: () => {},
  preparePortalMount: () => {},
  supportsMicrotasks: true,
  scheduleMicrotask: queueMicrotask,
};

export const wnkReconciler = ReactReconciler(hostConfig);
wnkReconciler.injectIntoDevTools({ bundleType: 1, version: '0.1.0', rendererPackageName: 'wnk-reconciler' });
