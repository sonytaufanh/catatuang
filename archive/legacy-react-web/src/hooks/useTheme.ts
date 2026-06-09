import { useEffect, useMemo, useState } from "react";
import type { ThemeMode } from "../types/finance";

export function useTheme(themeMode: ThemeMode, accent: string) {
  const [systemDark, setSystemDark] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia?.("(prefers-color-scheme: dark)");
    if (!mq) return;
    const update = () => setSystemDark(!!mq.matches);
    update();
    mq.addEventListener?.("change", update);
    // Safari fallback:
    // @ts-ignore
    mq.addListener?.(update);
    return () => {
      mq.removeEventListener?.("change", update);
      // @ts-ignore
      mq.removeListener?.(update);
    };
  }, []);

  const isDark = useMemo(() => {
    if (themeMode === "dark") return true;
    if (themeMode === "light") return false;
    return systemDark;
  }, [themeMode, systemDark]);

  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty("--accent", accent);
    if (isDark) root.classList.add("dark");
    else root.classList.remove("dark");
  }, [isDark, accent]);

  return { isDark, systemDark };
}