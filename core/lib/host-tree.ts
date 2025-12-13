// ============================================
// Host Tree - Virtual DOM for Wink
// Pure JS objects representing the UI tree
// ============================================

import type { ComponentType, SerializedNode, Style } from '../sdk/types';

// Internal node ID counter
let nodeIdCounter = 0;

// Generate unique node ID
function generateNodeId(): string {
  return `node_${++nodeIdCounter}`;
}

// Props that should not be serialized
const INTERNAL_PROPS = new Set(['children', 'key', 'ref']);

// WinkNode - represents a node in the virtual tree
export class WinkNode {
  public readonly id: string;
  public type: ComponentType;
  public props: Record<string, unknown>;
  public children: WinkNode[] = [];
  public parent: WinkNode | null = null;
  public text: string | null = null;

  constructor(type: ComponentType, props: Record<string, unknown> = {}) {
    this.id = generateNodeId();
    this.type = type;
    this.props = props;
  }

  // Append a child node
  appendChild(child: WinkNode): void {
    child.parent = this;
    this.children.push(child);
  }

  // Insert child before another child
  insertBefore(child: WinkNode, beforeChild: WinkNode): void {
    child.parent = this;
    const index = this.children.indexOf(beforeChild);
    if (index >= 0) {
      this.children.splice(index, 0, child);
    } else {
      this.children.push(child);
    }
  }

  // Remove a child node
  removeChild(child: WinkNode): void {
    const index = this.children.indexOf(child);
    if (index >= 0) {
      this.children.splice(index, 1);
      child.parent = null;
    }
  }

  // Update props
  updateProps(newProps: Record<string, unknown>): void {
    this.props = { ...this.props, ...newProps };
  }

  // Serialize to JSON-friendly object
  serialize(): SerializedNode {
    // Filter out internal props and functions
    const serializedProps: Record<string, unknown> = {};

    for (const [key, value] of Object.entries(this.props)) {
      if (INTERNAL_PROPS.has(key)) continue;
      if (typeof value === 'function') {
        // Mark as having event handler, but don't serialize the function
        serializedProps[`_has${key.charAt(0).toUpperCase() + key.slice(1)}`] = true;
        continue;
      }
      if (typeof value === 'symbol') continue;
      serializedProps[key] = value;
    }

    // Add node ID for event targeting
    serializedProps._nodeId = this.id;

    // Handle text content
    if (this.text !== null) {
      serializedProps.value = this.text;
    }

    return {
      type: this.type,
      props: serializedProps,
      children: this.children.map(child => child.serialize()),
    };
  }
}

// Root container - special node that holds the tree
export class WinkRoot {
  public child: WinkNode | null = null;
  private eventHandlers = new Map<string, Map<string, (...args: unknown[]) => void>>();

  // Set the root child
  setChild(node: WinkNode | null): void {
    this.child = node;
  }

  // Register an event handler for a node
  registerHandler(nodeId: string, eventName: string, handler: (...args: unknown[]) => void): void {
    if (!this.eventHandlers.has(nodeId)) {
      this.eventHandlers.set(nodeId, new Map());
    }
    this.eventHandlers.get(nodeId)!.set(eventName, handler);
  }

  // Unregister handlers for a node
  unregisterHandlers(nodeId: string): void {
    this.eventHandlers.delete(nodeId);
  }

  // Dispatch an event from host
  dispatchEvent(nodeId: string, eventName: string, payload?: unknown): void {
    const nodeHandlers = this.eventHandlers.get(nodeId);
    const handler = nodeHandlers?.get(eventName);
    if (handler) {
      handler(payload);
    }
  }

  // Serialize the entire tree
  serialize(): SerializedNode | null {
    return this.child?.serialize() ?? null;
  }
}

// Map component element types to our ComponentType
export function mapElementType(type: string): ComponentType {
  const typeMap: Record<string, ComponentType> = {
    'wink-box': 'Box',
    'wink-text': 'Text',
    'wink-button': 'Button',
    'wink-input': 'Input',
  };

  return typeMap[type] ?? 'Box';
}
