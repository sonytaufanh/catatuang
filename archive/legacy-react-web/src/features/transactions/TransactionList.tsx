import React from "react";
import type { Transaction } from "../../types/finance";
import { formatIDR } from "../../utils/money";
import { Trash2 } from "lucide-react";
import { AnimatePresence, motion } from "framer-motion";

export function TransactionList({
  txs,
  onDelete,
}: {
  txs: Transaction[];
  onDelete: (id: string) => void;
}) {
  if (txs.length === 0) {
    return (
      <div className="rounded-[var(--radius)] bg-white p-6 text-center shadow-sm ring-1 ring-neutral-100 dark:bg-neutral-900 dark:ring-neutral-800">
        <p className="text-base font-semibold">Belum ada transaksi</p>
        <p className="mt-1 text-sm text-neutral-500 dark:text-neutral-400">
          Tambahkan pemasukan & pengeluaran pertama kamu.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <AnimatePresence initial={false}>
        {txs.map((t) => {
          const isIncome = t.type === "income";
          return (
            <motion.div
              key={t.id}
              layout
              initial={{ opacity: 0, y: 10, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 10, scale: 0.98 }}
              transition={{ duration: 0.18 }}
              className="rounded-[var(--radius)] bg-white p-4 shadow-sm ring-1 ring-neutral-100 dark:bg-neutral-900 dark:ring-neutral-800"
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-bold">{t.category}</p>
                    <span className="text-xs text-neutral-400">•</span>
                    <p className="text-xs font-medium text-neutral-500 dark:text-neutral-400">{t.date}</p>
                    <span className="text-xs text-neutral-400">•</span>
                    <span
                      className={`rounded-full px-2 py-1 text-[11px] font-semibold ${
                        isIncome
                          ? "bg-emerald-50 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300"
                          : "bg-rose-50 text-rose-700 dark:bg-rose-900/30 dark:text-rose-300"
                      }`}
                    >
                      {isIncome ? "Masuk" : "Keluar"}
                    </span>
                  </div>

                  <p className="mt-1 text-sm text-neutral-700 dark:text-neutral-200">
                    {t.note || "Tanpa catatan"}
                  </p>

                  <p className="mt-2 text-xs font-semibold text-neutral-500 dark:text-neutral-400">
                    {t.paymentMethod}
                  </p>
                </div>

                <div className="text-right">
                  <p
                    className={`text-sm font-extrabold ${
                      isIncome ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
                    }`}
                  >
                    {isIncome ? "+" : "-"}
                    {formatIDR(t.amount)}
                  </p>

                  <button
                    className="mt-2 inline-flex items-center gap-1 rounded-xl bg-neutral-50 px-2 py-1 text-xs font-semibold text-neutral-600 ring-1 ring-neutral-100 active:scale-95 dark:bg-neutral-950 dark:text-neutral-300 dark:ring-neutral-800"
                    onClick={() => onDelete(t.id)}
                  >
                    <Trash2 className="h-3.5 w-3.5" /> Hapus
                  </button>
                </div>
              </div>
            </motion.div>
          );
        })}
      </AnimatePresence>
    </div>
  );
}