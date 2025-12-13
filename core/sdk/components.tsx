// ============================================
// wnk SDK Components
// React components that map to dvui primitives
// ============================================

import React from 'react';
import type {
  BoxProps,
  TextProps,
  ButtonProps,
  InputProps,
} from './types';

// Internal symbol to mark wnk components
export const wnk_COMPONENT = Symbol('wnk-component');

// Box - Flexbox container
export function Box(props: BoxProps): React.ReactElement {
  return React.createElement('wnk-box', {
    ...props,
    [wnk_COMPONENT]: true,
  });
}

// Text - Text display
export function Text(props: TextProps): React.ReactElement {
  return React.createElement('wnk-text', {
    ...props,
    [wnk_COMPONENT]: true,
  });
}

// Button - Interactive button
export function Button(props: ButtonProps): React.ReactElement {
  return React.createElement('wnk-button', {
    ...props,
    [wnk_COMPONENT]: true,
  });
}

// Input - Text input field
export function Input(props: InputProps): React.ReactElement {
  return React.createElement('wnk-input', {
    ...props,
    [wnk_COMPONENT]: true,
  });
}

// Type declarations for JSX
declare global {
  namespace JSX {
    interface IntrinsicElements {
      'wnk-box': BoxProps & { [wnk_COMPONENT]?: boolean };
      'wnk-text': TextProps & { [wnk_COMPONENT]?: boolean };
      'wnk-button': ButtonProps & { [wnk_COMPONENT]?: boolean };
      'wnk-input': InputProps & { [wnk_COMPONENT]?: boolean };
    }
  }
}
