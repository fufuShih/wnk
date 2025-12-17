import React from 'react';
import type { BoxProps, Style } from './types';
import type { ActionItem, PanelBottom, PanelTop } from './ipc';
import { wnk_COMPONENT } from './components';

function mergeStyles(style?: Style, styles?: Style): Style | undefined {
  if (!styles) return style;
  return { ...(style ?? {}), ...styles };
}

export type PanelProps = BoxProps & {
  top?: PanelTop;
  bottom?: PanelBottom;
  actions?: ActionItem[];
  dir?: 'vertical' | 'horizontal';
  gap?: number;
};

export function Panel(props: PanelProps): React.ReactElement {
  const { style, styles, ...rest } = props as PanelProps & { styles?: Style };
  return React.createElement('wnk-box', { ...rest, style: mergeStyles(style, styles), [wnk_COMPONENT]: true });
}

export type FlexProps = BoxProps & {
  gap?: number;
};

export function Flex(props: FlexProps): React.ReactElement {
  const { style, styles, ...rest } = props as FlexProps & { styles?: Style };
  return React.createElement('wnk-box', { ...rest, layout: 'flex', style: mergeStyles(style, styles), [wnk_COMPONENT]: true });
}

export type GridItemsProps = BoxProps & {
  columns?: number;
  gap?: number;
};

export function GridItems(props: GridItemsProps): React.ReactElement {
  const { columns, gap, style, styles, ...rest } = props as GridItemsProps & { styles?: Style };
  const merged = mergeStyles(style, styles);
  const nextStyle: Style = {
    ...(merged ?? {}),
    display: 'grid',
    gridColumns: columns ?? merged?.gridColumns,
    gridColumnGap: gap ?? merged?.gridColumnGap,
    gridRowGap: gap ?? merged?.gridRowGap,
  };
  return React.createElement('wnk-box', { ...rest, layout: 'grid', style: nextStyle, [wnk_COMPONENT]: true });
}

export type ItemProps = {
  id?: string;
  title: string;
  subtitle: string;
};

export function Item(props: ItemProps): React.ReactElement {
  return React.createElement('wnk-box', { ...props, [wnk_COMPONENT]: true });
}

