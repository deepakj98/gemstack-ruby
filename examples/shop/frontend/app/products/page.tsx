"use client";

import Link from "next/link";
import { Suspense } from "react";
import { ProductSearch } from "@/components/products/ProductSearch";
import { ProductTable } from "@/components/products/ProductTable";
import { useProducts } from "@/lib/queries/products";

export default function ProductsPage() {
  const products = useProducts();

  return (
    <main className="page">
      <header className="page-header">
        <h1>Products</h1>
        <Link className="button" href="/products/new">
          New product
        </Link>
      </header>
      <Suspense>
        <ProductSearch />
      </Suspense>
      <h2>All products</h2>
      {products.isPending && <p className="muted">Loading…</p>}
      {products.isError && <p className="form-error">Could not load products: {products.error.message}</p>}
      {products.data && <ProductTable products={products.data} />}
    </main>
  );
}
