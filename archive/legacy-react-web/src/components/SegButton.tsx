import React from "react";

export function SegButton({
  active,
  children,
  onClick,
}: {
  active: boolean;
  children: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={`flex-1 rounded-2xl px-3 py-2 text-sm font-semibold transition active:scale-[0.99] ${
        active ? "text-white" : "bg-white text-neutral-800 dark:bg-neutral-800 dark:text-neutral-100"
      }`}
      style={active ? { background: "var(--accent)" } : undefined}
    >
      {children}
    </button>
  );
}