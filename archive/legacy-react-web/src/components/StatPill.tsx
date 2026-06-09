import React from "react";

export function StatPill({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone?: "good" | "bad" | "neutral";
}) {
  const toneClass =
    tone === "good"
      ? "text-emerald-600 dark:text-emerald-400"
      : tone === "bad"
      ? "text-rose-600 dark:text-rose-400"
      : "text-neutral-900 dark:text-white";

  return (
    <div className="rounded-2xl bg-white p-3 shadow-sm ring-1 ring-neutral-100 dark:bg-neutral-900 dark:ring-neutral-800">
      <p className="text-xs font-semibold text-neutral-500 dark:text-neutral-400">{label}</p>
      <p className={`mt-1 text-sm font-extrabold ${toneClass}`}>{value}</p>
    </div>
  );
}