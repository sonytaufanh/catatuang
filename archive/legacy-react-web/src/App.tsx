import React, { useMemo, useState } from "react";
import { Settings, Plus, Download } from "lucide-react";
import type { AppState, ThemeMode, Transaction, TxType } from "./types/finance";
import { loadJSON, saveJSON } from "./utils/storage";
import { formatIDR } from "./utils/money";
import { inThisMonth, isSameDay, parseISODate, startOfDay, todayISO } from "./utils/dates";
import { parseQuickAdd } from "./utils/quickAdd";
import { useTheme } from "./hooks/useTheme";
import { BottomSheet } from "./components/BottomSheet";
import { SegButton } from "./components/SegButton";
import { Chip } from "./components/Chip";
import { StatPill } from "./components/StatPill";
import { TransactionForm } from "./features/transactions/TransactionForm";
import { TransactionList } from "./features/transactions/TransactionList";

const LS_KEY = "catatuang_tsx_v1";

const DEFAULT_STATE: AppState = {
  themeMode: "system",
  accent: "#0a0a0a",
  txs: [],
};

const ACCENT_PRESETS = ["#0a0a0a", "#0ea5e9", "#10b981", "#8b5cf6", "#f43f5e", "#f59e0b"];

export default function App() {
  const [state, setState] = useState<AppState>(() => loadJSON<AppState>(LS_KEY, DEFAULT_STATE));
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [addOpen, setAddOpen] = useState(false);
  const [addType, setAddType] = useState<TxType>("expense");

  const [filterType, setFilterType] = useState<"all" | TxType>("all");
  const [q, setQ] = useState("");
  const [quick, setQuick] = useState("");

  const { systemDark } = useTheme(state.themeMode, state.accent);

  function persist(next: AppState) {
    setState(next);
    saveJSON(LS_KEY, next);
  }

  const totals = useMemo(() => {
    const now = startOfDay(new Date());
    const incomeAll = state.txs.filter((t) => t.type === "income").reduce((a, t) => a + t.amount, 0);
    const expenseAll = state.txs.filter((t) => t.type === "expense").reduce((a, t) => a + t.amount, 0);

    const incomeMonth = state.txs.filter((t) => t.type === "income" && inThisMonth(t.date)).reduce((a, t) => a + t.amount, 0);
    const expenseMonth = state.txs.filter((t) => t.type === "expense" && inThisMonth(t.date)).reduce((a, t) => a + t.amount, 0);

    const incomeToday = state.txs
      .filter((t) => t.type === "income" && isSameDay(startOfDay(parseISODate(t.date)), now))
      .reduce((a, t) => a + t.amount, 0);
    const expenseToday = state.txs
      .filter((t) => t.type === "expense" && isSameDay(startOfDay(parseISODate(t.date)), now))
      .reduce((a, t) => a + t.amount, 0);

    return {
      incomeAll,
      expenseAll,
      incomeMonth,
      expenseMonth,
      incomeToday,
      expenseToday,
      balance: incomeAll - expenseAll,
    };
  }, [state.txs]);

  const filtered = useMemo(() => {
    let list = [...state.txs];
    if (filterType !== "all") list = list.filter((t) => t.type === filterType);
    const qq = q.trim().toLowerCase();
    if (qq) list = list.filter((t) => (`${t.category} ${t.note ?? ""} ${t.paymentMethod}`).toLowerCase().includes(qq));
    // newest first
    list.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : b.createdAt - a.createdAt));
    return list;
  }, [state.txs, filterType, q]);

  function openAdd(type: TxType) {
    setAddType(type);
    setAddOpen(true);
  }

  function addTx(tx: Transaction) {
    persist({ ...state, txs: [tx, ...state.txs] });
    setAddOpen(false);
  }

  function delTx(id: string) {
    if (!confirm("Hapus transaksi ini?")) return;
    persist({ ...state, txs: state.txs.filter((t) => t.id !== id) });
  }

  function addQuick() {
    const parsed = parseQuickAdd(quick);
    if (!parsed.ok) return alert(parsed.error);

    const tx: Transaction = {
      id: crypto.randomUUID?.() ?? String(Date.now()),
      type: parsed.type,
      date: todayISO(),
      category: parsed.type === "income" ? "Gaji" : "Lainnya",
      paymentMethod: "Cash",
      note: parsed.note || undefined,
      amount: parsed.amount,
      createdAt: Date.now(),
    };

    persist({ ...state, txs: [tx, ...state.txs] });
    setQuick("");
  }

  function exportBackup() {
    const payload = { version: 1, exportedAt: new Date().toISOString(), data: state };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `catatuang-backup-${todayISO()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div className="min-h-screen bg-neutral-50 text-neutral-900 transition-colors dark:bg-neutral-950 dark:text-white">
      <div className="mx-auto max-w-md p-5 pb-28">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-neutral-500 dark:text-neutral-400">PWA • Local-only</p>
            <h1 className="text-2xl font-bold tracking-tight">CatatUang</h1>
          </div>
          <button
            onClick={() => setSettingsOpen(true)}
            className="inline-flex items-center gap-2 rounded-2xl bg-white px-3 py-2 shadow-sm ring-1 ring-neutral-200 active:scale-95 dark:bg-neutral-900 dark:ring-neutral-800"
          >
            <Settings className="h-4 w-4" />
          </button>
        </div>
      <div className="sticky top-0 z-30 -mx-5 px-5 pb-3 pt-4 bg-neutral-100/85 backdrop-blur dark:bg-neutral-950/75">
  <div className="flex items-center justify-between">
    <div>
      <p className="text-xs font-semibold text-neutral-500 dark:text-neutral-400">PWA • Local-only</p>
      <h1 className="text-[22px] font-extrabold tracking-tight">CatatUang</h1>
    </div>
    <button
      onClick={() => setSettingsOpen(true)}
      className="h-11 w-11 rounded-2xl bg-white shadow-sm ring-1 ring-neutral-200 grid place-items-center active:scale-95 dark:bg-neutral-900 dark:ring-neutral-800"
      aria-label="Settings"
    >
      <Settings className="h-5 w-5" />
    </button>
  </div>
</div>

        {/* Summary */}
        <div className="mt-4 grid grid-cols-3 gap-2">
          <StatPill label="Masuk (hari)" value={formatIDR(totals.incomeToday)} tone="good" />
          <StatPill label="Keluar (hari)" value={formatIDR(totals.expenseToday)} tone="bad" />
          <StatPill label="Saldo" value={formatIDR(totals.balance)} tone={totals.balance >= 0 ? "good" : "bad"} />
        </div>

        {/* Quick add */}
        <div className="mt-3 rounded-3xl bg-white p-4 shadow-sm ring-1 ring-neutral-100 dark:bg-neutral-900 dark:ring-neutral-800">
          <p className="text-sm font-semibold">Quick Add</p>
          <p className="mt-1 text-sm text-neutral-500 dark:text-neutral-400">
            Contoh: <span className="font-semibold">+1500000 gaji</span> / <span className="font-semibold">-25000 makan</span>
          </p>
          <div className="mt-3 flex gap-2">
            <input
              value={quick}
              onChange={(e) => setQuick(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && addQuick()}
              placeholder="contoh: +1500000 gaji"
              className="w-full rounded-2xl border border-neutral-200 bg-white px-4 py-3 text-sm outline-none dark:border-neutral-800 dark:bg-neutral-950"
            />
            <button
              onClick={addQuick}
              className="rounded-2xl px-4 py-3 text-sm font-semibold text-white shadow active:scale-[0.99]"
              style={{ background: "var(--accent)" }}
            >
              Add
            </button>
          </div>
        </div>

        {/* Search + filters */}
        <div className="mt-4 flex gap-2">
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Cari transaksi..."
            className="w-full rounded-2xl border border-neutral-200 bg-white px-4 py-3 text-sm outline-none dark:border-neutral-800 dark:bg-neutral-950"
          />
          <button
            className="rounded-2xl bg-white px-3 py-2 shadow-sm ring-1 ring-neutral-100 active:scale-95 dark:bg-neutral-900 dark:ring-neutral-800"
            onClick={exportBackup}
            title="Backup"
          >
            <Download className="h-4 w-4" />
          </button>
        </div>

        <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
          <Chip active={filterType === "all"} onClick={() => setFilterType("all")}>Semua</Chip>
          <Chip active={filterType === "income"} onClick={() => setFilterType("income")}>Masuk</Chip>
          <Chip active={filterType === "expense"} onClick={() => setFilterType("expense")}>Keluar</Chip>
        </div>

        {/* List */}
        <div className="mt-3">
          <TransactionList txs={filtered} onDelete={delTx} />
        </div>
      </div>

      {/* Floating add */}
      <div className="fixed bottom-6 left-1/2 z-40 w-[min(92vw,420px)] -translate-x-1/2">
        <div className="grid grid-cols-2 gap-2">
          <button
            onClick={() => openAdd("expense")}
            className="rounded-2xl px-4 py-4 text-base font-semibold text-white shadow-2xl active:scale-[0.99]"
            style={{ background: "var(--accent)" }}
          >
            <span className="inline-flex items-center justify-center gap-2">
              <Plus className="h-5 w-5" /> Keluar
            </span>
          </button>
          <button
            onClick={() => openAdd("income")}
            className="rounded-2xl bg-white px-4 py-4 text-base font-semibold text-neutral-900 shadow-2xl ring-1 ring-neutral-200 active:scale-[0.99] dark:bg-neutral-900 dark:text-white dark:ring-neutral-800"
          >
            <span className="inline-flex items-center justify-center gap-2">
              <Plus className="h-5 w-5" /> Masuk
            </span>
          </button>
        </div>
      </div>

      {/* Add sheet */}
      <BottomSheet open={addOpen} title="Tambah Transaksi" onClose={() => setAddOpen(false)}>
        <TransactionForm initialType={addType} onSubmit={addTx} />
      </BottomSheet>

      {/* Settings sheet */}
      <BottomSheet open={settingsOpen} title="Pengaturan" onClose={() => setSettingsOpen(false)}>
        <div className="space-y-4">
          <div className="rounded-3xl bg-neutral-50 p-4 dark:bg-neutral-950">
            <p className="text-sm font-semibold">Mode Tema</p>
            <div className="mt-3 flex gap-2 rounded-3xl bg-neutral-100 p-1 dark:bg-neutral-900">
              {(["system", "light", "dark"] as ThemeMode[]).map((m) => (
                <SegButton key={m} active={state.themeMode === m} onClick={() => persist({ ...state, themeMode: m })}>
                  {m === "system" ? "System" : m === "light" ? "Light" : "Dark"}
                </SegButton>
              ))}
            </div>
            <p className="mt-2 text-xs font-semibold text-neutral-500 dark:text-neutral-400">
              System mengikuti tema HP (sekarang: {systemDark ? "Dark" : "Light"}).
            </p>
          </div>

          <div className="rounded-3xl bg-neutral-50 p-4 dark:bg-neutral-950">
            <p className="text-sm font-semibold">Accent</p>
            <div className="mt-3 grid grid-cols-3 gap-2">
              {ACCENT_PRESETS.map((c) => (
                <button
                  key={c}
                  onClick={() => persist({ ...state, accent: c })}
                  className="rounded-2xl px-3 py-3 text-xs font-semibold ring-1 ring-neutral-200 dark:ring-neutral-800"
                >
                  <span className="inline-flex items-center justify-center gap-2">
                    <span className="h-3 w-3 rounded-full" style={{ background: c }} />
                    {c}
                  </span>
                </button>
              ))}
            </div>

            <div className="mt-3 flex items-center gap-2">
              <label className="text-xs font-semibold text-neutral-600 dark:text-neutral-300">Custom</label>
              <input
                type="color"
                value={state.accent}
                onChange={(e) => persist({ ...state, accent: e.target.value })}
                className="h-10 w-14 rounded-xl border border-neutral-200 bg-white p-1 dark:border-neutral-800 dark:bg-neutral-900"
              />
            </div>
          </div>
        </div>
      </BottomSheet>
    </div>
  );
}