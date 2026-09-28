"use client";

// URL state (?q=) + server state (TanStack Query) + the generated, typed client.
import { useQuery } from "@tanstack/react-query";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { products } from "@/lib/api/generated";
import { ProductTable } from "./ProductTable";

export function ProductSearch() {
  const router = useRouter();
  const pathname = usePathname();
  const q = useSearchParams().get("q") ?? "";
  const results = useQuery({
    queryKey: ["products", "search", q],
    queryFn: () => products.search({ q }),
    enabled: q.trim().length >= 2,
  });

  return (
    <section>
      <input
        type="search"
        placeholder="Search products…"
        defaultValue={q}
        aria-label="Search products"
        onChange={(event) => {
          const value = event.target.value;
          router.replace(value ? `${pathname}?q=${encodeURIComponent(value)}` : pathname);
        }}
      />
      {results.data && <ProductTable products={results.data} />}
    </section>
  );
}
