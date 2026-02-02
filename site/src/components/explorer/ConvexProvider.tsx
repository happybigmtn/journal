"use client";

import { ConvexProvider as BaseConvexProvider, ConvexReactClient } from "convex/react";
import { ReactNode, useMemo } from "react";

const CONVEX_URL = import.meta.env.PUBLIC_CONVEX_URL || "http://5.161.124.82:3220";

export function ConvexProvider({ children }: { children: ReactNode }) {
  const client = useMemo(() => new ConvexReactClient(CONVEX_URL), []);
  return <BaseConvexProvider client={client}>{children}</BaseConvexProvider>;
}
