import React, { useEffect } from "react";
import { X } from "lucide-react";
import { AnimatePresence, motion } from "framer-motion";

type Props = {
  open: boolean;
  title: string;
  onClose: () => void;
  children: React.ReactNode;
};

export function BottomSheet({ open, title, onClose, children }: Props) {
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    if (open) window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  return (
    <AnimatePresence>
      {open && (
        <div className="fixed inset-0 z-50">
          {/* Backdrop */}
          <motion.div
            className="absolute inset-0 bg-black/55"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />

          {/* Sheet */}
          <motion.div
            className="absolute inset-x-0 bottom-0 mx-auto w-full max-w-md rounded-t-[26px] bg-white shadow-2xl dark:bg-neutral-900"
            initial={{ y: 520 }}
            animate={{ y: 0 }}
            exit={{ y: 520 }}
            transition={{ type: "spring", stiffness: 320, damping: 30 }}
          >
            <div className="px-5 pt-3 pb-2">
              <div className="mx-auto mb-2 h-1.5 w-10 rounded-full bg-neutral-200 dark:bg-neutral-700" />
              <div className="flex items-center justify-between">
                <h3 className="text-[16px] font-semibold text-neutral-900 dark:text-white">{title}</h3>
                <button
                  className="rounded-full p-2 active:scale-95"
                  onClick={onClose}
                  aria-label="Close"
                >
                  <X className="h-5 w-5 text-neutral-600 dark:text-neutral-300" />
                </button>
              </div>
            </div>

            <div className="px-5 pb-6">{children}</div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}