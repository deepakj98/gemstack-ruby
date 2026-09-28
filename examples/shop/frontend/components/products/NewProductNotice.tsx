"use client";

// Realtime: announced by the AnnounceProduct background job via GemStack.broadcast.
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import type { Product } from "@/lib/api/generated";
import { GAP_EVENT, useRealtime } from "@/lib/gemstack/realtime";
import { productKeys } from "@/lib/queries/products";

export function NewProductNotice() {
  const queryClient = useQueryClient();
  const [latest, setLatest] = useState<Product | null>(null);

  useRealtime<Product>("products", (event) => {
    // Refresh the list either way; a gap means we may have missed events while offline.
    void queryClient.invalidateQueries({ queryKey: productKeys.all });
    if (event.event === "product.created") setLatest(event.data);
    if (event.event === GAP_EVENT) setLatest(null);
  });

  if (!latest) return null;
  return (
    <p className="status status-ok" role="status">
      <span className="dot" aria-hidden="true" />
      New product just added: {latest.name} (€{latest.price})
    </p>
  );
}
