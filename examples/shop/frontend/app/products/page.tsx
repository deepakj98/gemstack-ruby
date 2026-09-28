"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { ProductSearch } from "@/components/products/ProductSearch";
import { ProductTable } from "@/components/products/ProductTable";
import { useProducts } from "@/lib/queries/products";

export default function ProductsPage() {
  return (
    <main className="page">
      <header className="page-header">
        <h1>Products</h1>
        <Link className="button" href="/products/new">
          New product
        </Link>
      </header>
      {/* useSearchParams needs a Suspense boundary for static rendering. */}
      <Suspense>
        <ProductSearch />
        <h2>All products</h2>
        <ProductsList />
      </Suspense>
    </main>
  );
}

// The current page lives in the URL (?page=2), so it survives reloads and can be shared.
function ProductsList() {
  const page = Math.max(1, Number(useSearchParams().get("page")) || 1);
  const products = useProducts(page);

  if (products.isPending) return <p className="muted">Loading…</p>;
  if (products.isError) return <p className="form-error">Could not load products: {products.error.message}</p>;

  const { data, meta } = products.data;
  return (
    <>
      <ProductTable products={data} />
      {meta.total_pages > 1 && (
        <nav className="actions" aria-label="Pagination">
          {page > 1 && <Link href={`?page=${page - 1}`}>← Previous</Link>}
          <span className="muted">
            Page {meta.page} of {meta.total_pages}
          </span>
          {page < meta.total_pages && <Link href={`?page=${page + 1}`}>Next →</Link>}
        </nav>
      )}
    </>
  );
}
