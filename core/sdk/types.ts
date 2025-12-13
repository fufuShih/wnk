// ============================================
// Wink SDK Type Definitions
// Protocol between Guest (Bun/React) and Host (Zig/dvui)
// ============================================

// Style properties that map to dvui styling
export interface Style {
  // Layout
  flexDirection?: 'row' | 'column';
  alignItems?: 'start' | 'center' | 'end' | 'stretch';
  justifyContent?: 'start' | 'center' | 'end' | 'space-between' | 'space-around';
  gap?: number;

  // Sizing
  width?: number | 'auto' | 'fill';
  height?: number | 'auto' | 'fill';
  minWidth?: number;
  minHeight?: number;
  maxWidth?: number;
  maxHeight?: number;

  // Spacing
  padding?: number | { x?: number; y?: number; top?: number; right?: number; bottom?: number; left?: number };
  margin?: number | { x?: number; y?: number; top?: number; right?: number; bottom?: number; left?: number };

  // Colors (hex string or rgba)
  backgroundColor?: string;
  color?: string;
  borderColor?: string;

  // Border
  borderWidth?: number;
  borderRadius?: number;

  // Text
  fontSize?: number;
  fontWeight?: 'normal' | 'bold';
  textAlign?: 'left' | 'center' | 'right';
}

// Base props for all components
export interface BaseProps {
  key?: string | number;
  style?: Style;
  children?: React.ReactNode;
}

// Box - container component (maps to dvui.box)
export interface BoxProps extends BaseProps {
  onPress?: () => void;
}

// Text - text display (maps to dvui.label)
export interface TextProps extends Omit<BaseProps, 'children'> {
  children?: string | number;
  bold?: boolean;
  italic?: boolean;
}

// Button - interactive button (maps to dvui.button)
export interface ButtonProps extends Omit<BaseProps, 'children'> {
  children?: string;
  onPress: () => void;
  disabled?: boolean;
  variant?: 'primary' | 'secondary' | 'ghost';
}

// Input - text input (maps to dvui.textEntry)
export interface InputProps extends Omit<BaseProps, 'children'> {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
  autoFocus?: boolean;
}

// Component types for the protocol
export type ComponentType = 'Box' | 'Text' | 'Button' | 'Input';

// Serialized node for IPC
export interface SerializedNode {
  type: ComponentType;
  props: Record<string, unknown>;
  children: SerializedNode[];
}

// Root payload sent to Host
export interface RenderPayload {
  version: 1;
  root: SerializedNode | null;
}

// Event from Host to Guest
export interface HostEvent {
  type: 'press' | 'change' | 'focus' | 'blur' | 'keydown';
  targetId: string;
  payload?: unknown;
}
