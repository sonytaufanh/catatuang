export type ThemeMode = "system" | "light" | "dark";
export type TxType = "income" | "expense";

export type Transaction = {
  id: string;
  type: TxType;
  date: string; // YYYY-MM-DD
  category: string;
  paymentMethod: string;
  note?: string;
  amount: number;
  createdAt: number;
};

export type AppState = {
  themeMode: ThemeMode;
  accent: string;
  txs: Transaction[];
};