import type { ComponentType, SerializedNode } from '../sdk/types';

let nodeIdCounter = 0;
const INTERNAL_PROPS = new Set(['children', 'key', 'ref']);

export class wnkNode {
  public readonly id = `node_${++nodeIdCounter}`;
  public type: ComponentType;
  public props: Record<string, unknown>;
  public children: wnkNode[] = [];
  public parent: wnkNode | null = null;
  public text: string | null = null;

  constructor(type: ComponentType, props: Record<string, unknown> = {}) {
    this.type = type;
    this.props = props;
  }

  appendChild(child: wnkNode): void {
    child.parent = this;
    this.children.push(child);
  }

  insertBefore(child: wnkNode, beforeChild: wnkNode): void {
    child.parent = this;
    const idx = this.children.indexOf(beforeChild);
    idx >= 0 ? this.children.splice(idx, 0, child) : this.children.push(child);
  }

  removeChild(child: wnkNode): void {
    const idx = this.children.indexOf(child);
    if (idx >= 0) { this.children.splice(idx, 1); child.parent = null; }
  }

  updateProps(newProps: Record<string, unknown>): void {
    this.props = { ...this.props, ...newProps };
  }

  serialize(): SerializedNode {
    const serializedProps: Record<string, unknown> = { _nodeId: this.id };
    for (const [key, value] of Object.entries(this.props)) {
      if (INTERNAL_PROPS.has(key) || typeof value === 'symbol') continue;
      if (typeof value === 'function') {
        serializedProps[`_has${key[0].toUpperCase()}${key.slice(1)}`] = true;
      } else {
        serializedProps[key] = value;
      }
    }
    if (this.text !== null) serializedProps.value = this.text;
    return { type: this.type, props: serializedProps, children: this.children.map(c => c.serialize()) };
  }
}

export class wnkRoot {
  public child: wnkNode | null = null;
  private rootChildren: wnkNode[] = [];
  private syntheticRoot: wnkNode | null = null;
  private handlers = new Map<string, Map<string, (...args: unknown[]) => void>>();

  setChild(node: wnkNode | null): void {
    this.rootChildren = node ? [node] : [];
    if (node) node.parent = null;
    this.syntheticRoot = null;
    this.child = node;
  }

  appendChildToContainer(child: wnkNode): void {
    child.parent = null;
    this.rootChildren.push(child);
    this.rebuildContainerRoot();
  }

  insertChildInContainerBefore(child: wnkNode, beforeChild: wnkNode): void {
    child.parent = null;
    const idx = this.rootChildren.indexOf(beforeChild);
    idx >= 0 ? this.rootChildren.splice(idx, 0, child) : this.rootChildren.push(child);
    this.rebuildContainerRoot();
  }

  removeChildFromContainer(child: wnkNode): void {
    const idx = this.rootChildren.indexOf(child);
    if (idx >= 0) this.rootChildren.splice(idx, 1);
    child.parent = null;
    this.unregisterSubtree(child);
    this.rebuildContainerRoot();
  }

  clearContainer(): void {
    for (const c of this.rootChildren) this.unregisterSubtree(c);
    this.rootChildren = [];
    this.syntheticRoot = null;
    this.child = null;
  }

  registerHandler(nodeId: string, event: string, handler: (...args: unknown[]) => void): void {
    if (!this.handlers.has(nodeId)) this.handlers.set(nodeId, new Map());
    this.handlers.get(nodeId)!.set(event, handler);
  }

  unregisterHandlers(nodeId: string): void { this.handlers.delete(nodeId); }

  dispatchEvent(nodeId: string, event: string, payload?: unknown): void {
    this.handlers.get(nodeId)?.get(event)?.(payload);
  }

  serialize(): SerializedNode | null { return this.child?.serialize() ?? null; }

  private rebuildContainerRoot(): void {
    if (this.rootChildren.length === 0) {
      this.child = null;
      this.syntheticRoot = null;
      return;
    }

    if (this.rootChildren.length === 1) {
      const only = this.rootChildren[0];
      only.parent = null;
      this.child = only;
      this.syntheticRoot = null;
      return;
    }

    if (!this.syntheticRoot) this.syntheticRoot = new wnkNode('Box', {});
    this.syntheticRoot.parent = null;
    this.syntheticRoot.children = [];

    for (const c of this.rootChildren) {
      c.parent = this.syntheticRoot;
      this.syntheticRoot.children.push(c);
    }

    this.child = this.syntheticRoot;
  }

  private unregisterSubtree(node: wnkNode): void {
    this.unregisterHandlers(node.id);
    for (const c of node.children) this.unregisterSubtree(c);
  }
}

const TYPE_MAP: Record<string, ComponentType> = {
  'wnk-box': 'Box', 'wnk-text': 'Text', 'wnk-button': 'Button', 'wnk-input': 'Input'
};
export function mapElementType(type: string): ComponentType { return TYPE_MAP[type] ?? 'Box'; }
