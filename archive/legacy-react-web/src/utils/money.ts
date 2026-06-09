export function formatIDR(n: number) {
  return Number(n || 0).toLocaleString("id-ID", {
    style: "currency",
    currency: "IDR",
  });
}

export function parseMoney(input: string) {
  const s = String(input ?? "").trim();
  const cleaned = s.replace(/\./g, "").replace(/,/g, "");
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : 0;
}