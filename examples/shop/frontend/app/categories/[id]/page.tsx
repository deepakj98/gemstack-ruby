"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { CategoryCard } from "@/components/categories/CategoryCard";
import { useCategory, useDeleteCategory } from "@/lib/queries/categories";

export default function CategoryPage() {
  const { id } = useParams<{ id: string }>();
  const category = useCategory(id);
  const router = useRouter();
  const remove = useDeleteCategory();

  async function handleDelete() {
    if (!window.confirm("Delete this category?")) return;
    await remove.mutateAsync(id);
    router.push("/categories");
  }

  return (
    <main className="page">
      <p>
        <Link href="/categories">← Categories</Link>
      </p>
      {category.isPending && <p className="muted">Loading…</p>}
      {category.isError && <p className="form-error">{category.error.message}</p>}
      {category.data && (
        <>
          <h1>Category #{category.data.id}</h1>
          <CategoryCard category={category.data} />
          <div className="actions">
            <Link className="button" href={`/categories/${id}/edit`}>
              Edit
            </Link>
            <button className="button button-danger" type="button" onClick={handleDelete} disabled={remove.isPending}>
              Delete
            </button>
          </div>
        </>
      )}
    </main>
  );
}
