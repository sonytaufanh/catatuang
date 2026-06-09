import React, { useMemo, useState } from "react";
import type { Transaction, TxType } from "../../types/finance";
import { parseMoney } from "../../utils/money";
import { todayISO } from "../../utils/dates";

const EXPENSE = ["Makan", "Transport", "Belanja", "Tagihan", "Hiburan", "Kesehatan", "Pendidikan", "Lainnya"];
const INCOME = ["Gaji", "Bonus", "Freelance", "Investasi", "Hadiah", "Lainnya"];
const PAYMENT = ["Cash", "E-Wallet", "Debit", "Credit"];

function uid() {
  return Math.random().toString(16).slice(2) + Date.now().toString(16);
}

export function TransactionForm({
  onSubmit,
  initialType = "expense",
}: {
  onSubmit: (tx: Transaction) => void;
  initialType?: TxType;
}) {
  const [type, setType] = useState<TxType>(initialType);
  const [date, setDate] = useState(todayISO());
  const [category, setCategory] = useState(type === "income" ? INCOME[0] : EXPENSE[0]);
  const [paymentMethod, setPaymentMethod] = useState(PAYMENT[0]);
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");

  const cats = useMemo(() => (type === "income" ? INCOME : EXPENSE), [type]);

  function submit() {
    const a = parseMoney(amount);
    if (!date) return alert("Tanggal wajib");
    if (!category) return alert("Kategori wajib");
    if (!paymentMethod) return alert("Metode wajib");
    if (!a || a <= 0) return alert("Nominal harus > 0");

    onSubmit({
      id: uid(),
      type,
      date,
      category,
      paymentMethod,
      note: note.trim() || undefined,
      amount: a,
      createdAt: Date.now(),
    });
  }

  return (
    <div className="space-y-3">
      <div className="rounded-3xl bg-neutral-50 p-4 dark:bg-neutral-950">
        <p className="text-sm font-semibold">Jenis</p>
        <div className="mt-2 flex gap-2 rounded-3xl bg-neutral-100 p-1 dark:bg-neutral-900">
          <button
            className={`flex-1 rounded-2xl px-3 py-2 text-sm font-semibold ${type === "expense" ? "text-white" : ""}`}
            style={type === "expense" ? { background: "var(--accent)" } : undefined}
            onClick={() => {
              setType("expense");
              setCategory(EXPENSE[0]);
            }}
          >
            Keluar
          </button>
          <button
            className={`flex-1 rounded-2xl px-3 py-2 text-sm font-semibold ${type === "income" ? "text-white" : ""}`}
            style={type === "income" ? { background: "var(--accent)" } : undefined}
            onClick={() => {
              setType("income");
              setCategory(INCOME[0]);
            }}
          >
            Masuk
          </button>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="text-xs font-semibold text-neutral-600 dark:text-neutral-300">Tanggal</label>
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="mt-1 w-full rounded-2xl border border-neutral-200 bg-white px-4 py-3 text-sm outline-none dark:border-neutral-800 dark:bg-neutral-950"
          />
        </div>
        <div>
          <label className="text-xs font-semibold text-neutral-600 dark:text-neutral-300">Nominal</label>
          <input
            inputMode="numeric"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="contoh: 25000"
            className="mt-1 w-full rounded-2xl border border-neutral-200 bg-white px-4 py-3 text-sm outline-none dark:border-neutral-800 dark:bg-neutral-950"
          />
        </div>
      </div>

      <div>
        <label className="text-xs font-semibold text-neutral-600 dark:text-neutral-300">Kategori</label>
        <div className="mt-2 flex flex-wrap gap-2">
          {cats.map((c) => (
            <button
              key={c}
              onClick={() => setCategory(c)}
              className={`rounded-full px-3 py-2 text-sm font-semibold ${category === c ? "text-white" : "bg-neutral-100 dark:bg-neutral-900"}`}
              style={category === c ? { background: "var(--accent)" } : undefined}
            >
              {c}
            </button>
          ))}
        </div>
      </div>

      <div>
        <label className="text-xs font-semibold text-neutral-600 dark:text-neutral-300">Metode</label>
        <div className="mt-2 grid grid-cols-2 gap-2">
          {PAYMENT.map((p) => (
            <button
              key={p}
              onClick={() => setPaymentMethod(p)}
              className={`rounded-2xl px-3 py-3 text-sm font-semibold ring-1 ${
                paymentMethod === p ? "text-white ring-transparent" : "bg-white ring-neutral-200 dark:bg-neutral-950 dark:ring-neutral-800"
              }`}
              style={paymentMethod === p ? { background: "var(--accent)" } : undefined}
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      <div>
        <label className="text-xs font-semibold text-neutral-600 dark:text-neutral-300">Catatan</label>
        <input
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder={type === "income" ? "mis: gaji Januari" : "mis: kopi + roti"}
          className="mt-1 w-full rounded-2xl border border-neutral-200 bg-white px-4 py-3 text-sm outline-none dark:border-neutral-800 dark:bg-neutral-950"
        />
      </div>

      <button
        onClick={submit}
        className="w-full rounded-2xl px-4 py-4 text-base font-semibold text-white shadow active:scale-[0.99]"
        style={{ background: "var(--accent)" }}
      >
        Simpan
      </button>
    </div>
  );
}