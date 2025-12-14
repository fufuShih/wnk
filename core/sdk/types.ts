type Spacing = number | { x?: number; y?: number; top?: number; right?: number; bottom?: number; left?: number };

export interface Style {
  display?: 'flex' | 'grid';
  flexDirection?: 'row' | 'column';
  alignItems?: 'start' | 'center' | 'end' | 'stretch';
  justifyContent?: 'start' | 'center' | 'end' | 'space-between' | 'space-around';
  gap?: number;

  // Grid (host may ignore if unsupported)
  gridColumns?: number;
  gridRows?: number;
  gridColumnGap?: number;
  gridRowGap?: number;

  width?: number | 'auto' | 'fill';
  height?: number | 'auto' | 'fill';
  minWidth?: number;
  minHeight?: number;
  maxWidth?: number;
  maxHeight?: number;
  padding?: Spacing;
  margin?: Spacing;
  backgroundColor?: string;
  color?: string;
  borderColor?: string;
  borderWidth?: number;
  borderRadius?: number;
  fontSize?: number;
  fontWeight?: 'normal' | 'bold';
  textAlign?: 'left' | 'center' | 'right';
}

export interface BaseProps {
  key?: string | number;
  style?: Style;
  children?: React.ReactNode;
}

export interface BoxProps extends BaseProps { onPress?: () => void; }
export interface TextProps extends Omit<BaseProps, 'children'> { children?: string | number; bold?: boolean; italic?: boolean; }
export interface ButtonProps extends Omit<BaseProps, 'children'> { children?: string; onPress: () => void; disabled?: boolean; variant?: 'primary' | 'secondary' | 'ghost'; }
export interface InputProps extends Omit<BaseProps, 'children'> { value: string; onChange: (value: string) => void; placeholder?: string; disabled?: boolean; autoFocus?: boolean; }

export type ComponentType = 'Box' | 'Text' | 'Button' | 'Input';

export interface SerializedNode { type: ComponentType; props: Record<string, unknown>; children: SerializedNode[]; }
export interface RenderPayload { version: 1; root: SerializedNode | null; }
export interface HostEvent { type: 'press' | 'change' | 'focus' | 'blur' | 'keydown'; targetId: string; payload?: unknown; }
