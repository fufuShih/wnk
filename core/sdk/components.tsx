// ============================================
// Wink SDK Components
// React components that map to dvui primitives
// ============================================

import React from 'react';
import type {
  BoxProps,
  TextProps,
  ButtonProps,
  InputProps,
} from './types';

// Internal symbol to mark Wink components
export const WINK_COMPONENT = Symbol('wink-component');

// Box - Flexbox container
export function Box(props: BoxProps): React.ReactElement {
  return React.createElement('wink-box', {
    ...props,
    [WINK_COMPONENT]: true,
  });
}

// Text - Text display
export function Text(props: TextProps): React.ReactElement {
  return React.createElement('wink-text', {
    ...props,
    [WINK_COMPONENT]: true,
  });
}

// Button - Interactive button
export function Button(props: ButtonProps): React.ReactElement {
  return React.createElement('wink-button', {
    ...props,
    [WINK_COMPONENT]: true,
  });
}

// Input - Text input field
export function Input(props: InputProps): React.ReactElement {
  return React.createElement('wink-input', {
    ...props,
    [WINK_COMPONENT]: true,
  });
}

// Type declarations for JSX
declare global {
  namespace JSX {
    interface IntrinsicElements {
      'wink-box': BoxProps & { [WINK_COMPONENT]?: boolean };
      'wink-text': TextProps & { [WINK_COMPONENT]?: boolean };
      'wink-button': ButtonProps & { [WINK_COMPONENT]?: boolean };
      'wink-input': InputProps & { [WINK_COMPONENT]?: boolean };
    }
  }
}
