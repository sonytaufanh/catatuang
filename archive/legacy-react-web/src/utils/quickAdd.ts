import type { TxType } from "../types/finance";

export type QuickParsed =
  | { ok: true; type: TxType; amount: number; note: string }
  | { ok: false; error: string };

export function parseQuickAdd(input: string): QuickParsed {
  const raw = String(input || "").trim();
  if (!raw) return { ok: false, error: "Kosong" };

  let type: TxType = "expense";
  if (raw.startsWith("+")) type = "income";
  if (raw.startsWith("-")) type = "expense";

  const cleaned = raw.replace(/^[-+]/, "").trim();
  const m = cleaned.replace(/\./g, "").match(/(\d+[\d,]*)/);
  if (!m) return { ok: false, error: "Nominal tidak ketemu. Contoh: +1500000 gaji" };

  const amount = Number(m[1].replace(/,/g, ""));
  if (!amount || amount <= 0) return { ok: false, error: "Nominal harus > 0" };

  const note = cleaned.replace(m[0], " ").replace(/\s+/g, " ").trim();
  return { ok: true, type, amount, note };
}