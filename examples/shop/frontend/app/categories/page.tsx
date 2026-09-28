"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { CategoryTable } from "@/components/categories/CategoryTable";
import { useCategories } from "@/lib/queries/categories";

export default function CategoriesPage() {
  return (
    <main className="page">
      <header className="page-header">
        <h1>Categories</h1>
        <Link className="button" href="/categories/new">
          New category
        </Link>
      </header>
      {/* useSearchParams needs a Suspense boundary for static rendering. */}
      <Suspense>
        <CategoriesList />
      </Suspense>
    </main>
  );
}

// The current page lives in the URL (?page=2), so it survives reloads and can be shared.
function CategoriesList() {
  const page = Math.max(1, Number(useSearchParams().get("page")) || 1);
  const categories = useCategories(page);

  if (categories.isPending) return <p className="muted">Loading…</p>;
  if (categories.isError) return <p className="form-error">Could not load categories: {categories.error.message}</p>;

  const { data, meta } = categories.data;
  return (
    <>
      <CategoryTable categories={data} />
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
