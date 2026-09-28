"use client";

import Link from "next/link";
import { CategoryTable } from "@/components/categories/CategoryTable";
import { useCategories } from "@/lib/queries/categories";

export default function CategoriesPage() {
  const categories = useCategories();

  return (
    <main className="page">
      <header className="page-header">
        <h1>Categories</h1>
        <Link className="button" href="/categories/new">
          New category
        </Link>
      </header>
      {categories.isPending && <p className="muted">Loading…</p>}
      {categories.isError && <p className="form-error">Could not load categories: {categories.error.message}</p>}
      {categories.data && <CategoryTable categories={categories.data} />}
    </main>
  );
}
