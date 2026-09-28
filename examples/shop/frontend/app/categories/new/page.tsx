"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { CategoryForm } from "@/components/categories/CategoryForm";
import { useCreateCategory } from "@/lib/queries/categories";

export default function NewCategoryPage() {
  const router = useRouter();
  const create = useCreateCategory();

  return (
    <main className="page">
      <p>
        <Link href="/categories">← Categories</Link>
      </p>
      <h1>New category</h1>
      <CategoryForm
        submitLabel="Create category"
        onSubmit={async (input) => {
          const category = await create.mutateAsync(input);
          router.push(`/categories/${category.id}`);
        }}
      />
    </main>
  );
}
