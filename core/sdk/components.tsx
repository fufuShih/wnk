import React from 'react';
import type { BoxProps, TextProps, ButtonProps, InputProps } from './types';

export const wnk_COMPONENT = Symbol('wnk-component');

const c = <P extends { style?: any; styles?: any },>(tag: string) => (props: P): React.ReactElement => {
  const { style, styles, ...rest } = props as any;
  const mergedStyle = styles ? { ...(style ?? {}), ...(styles ?? {}) } : style;
  return React.createElement(tag, { ...rest, style: mergedStyle, [wnk_COMPONENT]: true });
};

export const Box = c<BoxProps>('wnk-box');
export const Text = c<TextProps>('wnk-text');
export const Button = c<ButtonProps>('wnk-button');
export const Input = c<InputProps>('wnk-input');

export function Row(props: BoxProps): React.ReactElement {
  const { style, styles, ...rest } = props as any;
  const nextStyle = { ...(style ?? {}), ...(styles ?? {}), display: 'flex' as const, flexDirection: 'row' as const };
  return React.createElement('wnk-box', { ...rest, style: nextStyle, [wnk_COMPONENT]: true });
}

export function Column(props: BoxProps): React.ReactElement {
  const { style, styles, ...rest } = props as any;
  const nextStyle = { ...(style ?? {}), ...(styles ?? {}), display: 'flex' as const, flexDirection: 'column' as const };
  return React.createElement('wnk-box', { ...rest, style: nextStyle, [wnk_COMPONENT]: true });
}

export function Grid(props: BoxProps & { columns?: number; columnGap?: number; rowGap?: number }): React.ReactElement {
  const { columns, columnGap, rowGap, style: styleProp, styles, ...rest } = props as any;
  const baseStyle = { ...(styleProp ?? {}), ...(styles ?? {}) };
  const nextStyle = {
    ...baseStyle,
    display: 'grid' as const,
    gridColumns: columns ?? baseStyle.gridColumns,
    gridColumnGap: columnGap ?? baseStyle.gridColumnGap,
    gridRowGap: rowGap ?? baseStyle.gridRowGap,
  };
  return React.createElement('wnk-box', { ...rest, style: nextStyle, [wnk_COMPONENT]: true });
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
