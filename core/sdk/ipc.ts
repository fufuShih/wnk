export type ResultItem = {
  id?: string;
  title: string;
  subtitle?: string;
  icon?: string;
};

export type PanelItem = {
  id?: string;
  title: string;
  subtitle: string;
  has_actions?: boolean;
};

export type ActionItem = {
  name: string;
  title: string;
  text?: string;
  close_on_execute?: boolean;
  host_only?: boolean;
  input?: { placeholder?: string; initial?: string };
};

export type PanelTop =
  | { type: 'header'; title: string; subtitle?: string }
  | { type: 'selected' };

export type PanelBottom =
  | { type: 'none' }
  | { type: 'info'; text: string };

export type PanelNode =
  | {
      type: 'box';
      layout?: 'flex' | 'grid';
      dir?: 'vertical' | 'horizontal';
      gap?: number;
      columns?: number;
      items?: PanelItem[];
      children?: PanelNode[];
    }
  // Legacy node kinds (still accepted by the host).
  | { type: 'flex'; items: PanelItem[] }
  | { type: 'grid'; columns?: number; gap?: number; items: PanelItem[] };

export type PanelData = {
  top: PanelTop;
  main: PanelNode;
  bottom?: PanelBottom;
};
