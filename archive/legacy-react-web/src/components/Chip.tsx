import React from "react";

export function Chip({
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
      className={`whitespace-nowrap rounded-full px-3 py-1.5 text-sm font-semibold transition active:scale-[0.99] ${
        active ? "text-white" : "bg-neutral-100 text-neutral-800 dark:bg-neutral-900 dark:text-neutral-200"
      }`}
      style={active ? { background: "var(--accent)" } : undefined}
    >
      {children}
    </button>
  );
}