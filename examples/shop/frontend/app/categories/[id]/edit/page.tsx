"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { CategoryForm } from "@/components/categories/CategoryForm";
import { useCategory, useUpdateCategory } from "@/lib/queries/categories";

export default function EditCategoryPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const category = useCategory(id);
  const update = useUpdateCategory(id);

  return (
    <main className="page">
      <p>
        <Link href="/categories/${id}">← Back</Link>
      </p>
      <h1>Edit category</h1>
      {category.isPending && <p className="muted">Loading…</p>}
      {category.data && (
        <CategoryForm
          category={category.data}
          submitLabel="Save changes"
          onSubmit={async (input) => {
            await update.mutateAsync(input);
            router.push(`/categories/${id}`);
          }}
        />
      )}
    </main>
  );
}
