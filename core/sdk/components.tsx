import React from 'react';
import type { BoxProps, TextProps, ButtonProps, InputProps } from './types';

export const wnk_COMPONENT = Symbol('wnk-component');

const c = <P,>(tag: string) => (props: P): React.ReactElement =>
  React.createElement(tag, { ...props, [wnk_COMPONENT]: true });

export const Box = c<BoxProps>('wnk-box');
export const Text = c<TextProps>('wnk-text');
export const Button = c<ButtonProps>('wnk-button');
export const Input = c<InputProps>('wnk-input');

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
