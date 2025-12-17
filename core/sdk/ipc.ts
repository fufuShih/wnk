export type ResultItem = {
  id?: string;
  title: string;
  subtitle?: string;
  icon?: string;
};

export type SubpanelItem = {
  id?: string;
  title: string;
  subtitle: string;
};

export type ActionItem = {
  name: string;
  title: string;
  text?: string;
  close_on_execute?: boolean;
};

export type PanelTop =
  | { type: 'header'; title: string; subtitle?: string }
  | { type: 'selected' };

export type PanelBottom =
  | { type: 'none' }
  | { type: 'info'; text: string };

export type PanelNode =
  | { type: 'flex'; items: SubpanelItem[] }
  | { type: 'grid'; columns?: number; gap?: number; items: SubpanelItem[] }
  | { type: 'box'; dir?: 'vertical' | 'horizontal'; gap?: number; children: PanelNode[] };

export type SubpanelData = {
  top: PanelTop;
  main: PanelNode;
  bottom?: PanelBottom;
};

