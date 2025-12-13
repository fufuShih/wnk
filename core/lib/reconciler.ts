// ============================================
// wnk Reconciler
// Custom React Reconciler using react-reconciler
// Inspired by Ink's architecture
// ============================================

import ReactReconciler from 'react-reconciler';
import { DefaultEventPriority } from 'react-reconciler/constants';
import { wnkNode, wnkRoot, mapElementType } from './host-tree';

// The container type (root of our tree)
type Container = wnkRoot;
type Instance = wnkNode;
type TextInstance = wnkNode;
type ChildSet = never;
type PublicInstance = wnkNode;
type HostContext = Record<string, never>;
type UpdatePayload = Record<string, unknown>;
type TimeoutHandle = ReturnType<typeof setTimeout>;
type NoTimeout = -1;
type SuspenseInstance = never;

// Callback to notify when tree updates
let onTreeUpdate: ((root: wnkRoot) => void) | null = null;

export function setTreeUpdateCallback(callback: (root: wnkRoot) => void): void {
  onTreeUpdate = callback;
}

// Host config for react-reconciler
const hostConfig: ReactReconciler.HostConfig<
  string,               // Type
  Record<string, unknown>, // Props
  Container,
  Instance,
  TextInstance,
  SuspenseInstance,
  never,               // HydratableInstance
  PublicInstance,
  HostContext,
  UpdatePayload,
  ChildSet,
  TimeoutHandle,
  NoTimeout
> = {
  // ============ Core Methods ============

  createInstance(
    type: string,
    props: Record<string, unknown>,
    rootContainer: Container
  ): Instance {
    const componentType = mapElementType(type);
    const node = new wnkNode(componentType, props);

    // Capture inline text children (React may not create a TextInstance when
    // shouldSetTextContent() is true).
    const children = props.children;
    if (typeof children === 'string' || typeof children === 'number') {
      node.text = String(children);
    }

    // Register event handlers
    if (props.onPress && typeof props.onPress === 'function') {
      rootContainer.registerHandler(node.id, 'onPress', props.onPress as () => void);
    }
    if (props.onChange && typeof props.onChange === 'function') {
      rootContainer.registerHandler(node.id, 'onChange', props.onChange as (...args: unknown[]) => void);
    }

    return node;
  },

  createTextInstance(
    text: string,
    _rootContainer: Container
  ): TextInstance {
    const node = new wnkNode('Text', {});
    node.text = text;
    return node;
  },

  appendInitialChild(parentInstance: Instance, child: Instance | TextInstance): void {
    parentInstance.appendChild(child);
  },

  appendChild(parentInstance: Instance, child: Instance | TextInstance): void {
    parentInstance.appendChild(child);
  },

  appendChildToContainer(container: Container, child: Instance): void {
    container.setChild(child);
    onTreeUpdate?.(container);
  },

  insertBefore(
    parentInstance: Instance,
    child: Instance | TextInstance,
    beforeChild: Instance | TextInstance
  ): void {
    parentInstance.insertBefore(child, beforeChild);
  },

  insertInContainerBefore(
    container: Container,
    child: Instance,
    _beforeChild: Instance
  ): void {
    container.setChild(child);
    onTreeUpdate?.(container);
  },

  removeChild(parentInstance: Instance, child: Instance | TextInstance): void {
    parentInstance.removeChild(child);
  },

  removeChildFromContainer(container: Container, child: Instance): void {
    if (container.child === child) {
      container.unregisterHandlers(child.id);
      container.setChild(null);
    }
    onTreeUpdate?.(container);
  },

  // ============ Update Methods ============

  prepareUpdate(
    _instance: Instance,
    _type: string,
    oldProps: Record<string, unknown>,
    newProps: Record<string, unknown>
  ): UpdatePayload | null {
    const updatePayload: UpdatePayload = {};
    let hasChanges = false;

    // Check for changed props
    for (const key of Object.keys(newProps)) {
      if (key === 'children') {
        const oldChildren = oldProps.children;
        const newChildren = newProps.children;
        const oldIsText = typeof oldChildren === 'string' || typeof oldChildren === 'number';
        const newIsText = typeof newChildren === 'string' || typeof newChildren === 'number';

        if ((oldIsText || newIsText) && oldChildren !== newChildren) {
          // Keep as internal prop; host-tree won't serialize 'children'.
          updatePayload.children = newChildren;
          hasChanges = true;
        }
        continue;
      }
      if (oldProps[key] !== newProps[key]) {
        updatePayload[key] = newProps[key];
        hasChanges = true;
      }
    }

    // Check for removed props
    for (const key of Object.keys(oldProps)) {
      if (key === 'children') {
        const oldChildren = oldProps.children;
        const newChildren = newProps.children;
        const oldIsText = typeof oldChildren === 'string' || typeof oldChildren === 'number';
        const newIsText = typeof newChildren === 'string' || typeof newChildren === 'number';

        if ((oldIsText || newIsText) && oldChildren !== newChildren) {
          updatePayload.children = newChildren;
          hasChanges = true;
        }
        continue;
      }
      if (!(key in newProps)) {
        updatePayload[key] = undefined;
        hasChanges = true;
      }
    }

    return hasChanges ? updatePayload : null;
  },

  commitUpdate(
    instance: Instance,
    updatePayload: UpdatePayload,
    _type: string,
    _prevProps: Record<string, unknown>,
    nextProps: Record<string, unknown>
  ): void {
    instance.updateProps(updatePayload);

    const children = nextProps.children;
    if (typeof children === 'string' || typeof children === 'number') {
      instance.text = String(children);
    } else {
      instance.text = null;
    }
  },

  commitTextUpdate(
    textInstance: TextInstance,
    _oldText: string,
    newText: string
  ): void {
    textInstance.text = newText;
  },

  // ============ Finalization ============

  finalizeInitialChildren(): boolean {
    return false;
  },

  prepareForCommit(): Record<string, unknown> | null {
    return null;
  },

  resetAfterCommit(container: Container): void {
    onTreeUpdate?.(container);
  },

  // ============ Host Context ============

  getRootHostContext(): HostContext {
    return {};
  },

  getChildHostContext(): HostContext {
    return {};
  },

  // ============ Misc ============

  getPublicInstance(instance: Instance): PublicInstance {
    return instance;
  },

  shouldSetTextContent(_type: string, props: Record<string, unknown>): boolean {
    // Text nodes for string children
    return typeof props.children === 'string' || typeof props.children === 'number';
  },

  clearContainer(container: Container): void {
    if (container.child) {
      container.unregisterHandlers(container.child.id);
    }
    container.setChild(null);
  },

  // ============ Scheduling ============

  supportsMutation: true,
  supportsPersistence: false,
  supportsHydration: false,

  isPrimaryRenderer: true,
  warnsIfNotActing: true,

  scheduleTimeout: setTimeout,
  cancelTimeout: clearTimeout,
  noTimeout: -1 as NoTimeout,

  getCurrentEventPriority: () => DefaultEventPriority,
  getInstanceFromNode: () => null,
  beforeActiveInstanceBlur: () => {},
  afterActiveInstanceBlur: () => {},
  prepareScopeUpdate: () => {},
  getInstanceFromScope: () => null,
  detachDeletedInstance: () => {},

  // Required methods
  preparePortalMount: () => {},

  // Microtask support
  supportsMicrotasks: true,
  scheduleMicrotask: queueMicrotask,
};

// Create the reconciler
export const wnkReconciler = ReactReconciler(hostConfig);

// Enable concurrent features
wnkReconciler.injectIntoDevTools({
  bundleType: 1, // 0 for production, 1 for development
  version: '0.1.0',
  rendererPackageName: 'wnk-reconciler',
});
