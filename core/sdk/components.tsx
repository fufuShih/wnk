import React from 'react';
import type { BoxProps, TextProps, ButtonProps, InputProps } from './types';

export const wnk_COMPONENT = Symbol('wnk-component');

const c = <P,>(tag: string) => (props: P): React.ReactElement =>
  React.createElement(tag, { ...props, [wnk_COMPONENT]: true });

export const Box = c<BoxProps>('wnk-box');
export const Text = c<TextProps>('wnk-text');
export const Button = c<ButtonProps>('wnk-button');
export const Input = c<InputProps>('wnk-input');

export function Row(props: BoxProps): React.ReactElement {
  const style = { ...(props.style ?? {}), display: 'flex' as const, flexDirection: 'row' as const };
  return React.createElement('wnk-box', { ...props, style, [wnk_COMPONENT]: true });
}

export function Column(props: BoxProps): React.ReactElement {
  const style = { ...(props.style ?? {}), display: 'flex' as const, flexDirection: 'column' as const };
  return React.createElement('wnk-box', { ...props, style, [wnk_COMPONENT]: true });
}

export function Grid(props: BoxProps & { columns?: number; columnGap?: number; rowGap?: number }): React.ReactElement {
  const { columns, columnGap, rowGap, ...rest } = props;
  const style = {
    ...(rest.style ?? {}),
    display: 'grid' as const,
    gridColumns: columns ?? (rest.style as any)?.gridColumns,
    gridColumnGap: columnGap ?? (rest.style as any)?.gridColumnGap,
    gridRowGap: rowGap ?? (rest.style as any)?.gridRowGap,
  };
  return React.createElement('wnk-box', { ...rest, style, [wnk_COMPONENT]: true });
}

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
