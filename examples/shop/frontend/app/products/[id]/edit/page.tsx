"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ProductForm } from "@/components/products/ProductForm";
import { useProduct, useUpdateProduct } from "@/lib/queries/products";

export default function EditProductPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const product = useProduct(id);
  const update = useUpdateProduct(id);

  return (
    <main className="page">
      <p>
        <Link href="/products/${id}">← Back</Link>
      </p>
      <h1>Edit product</h1>
      {product.isPending && <p className="muted">Loading…</p>}
      {product.data && (
        <ProductForm
          product={product.data}
          submitLabel="Save changes"
          onSubmit={async (input) => {
            await update.mutateAsync(input);
            router.push(`/products/${id}`);
          }}
        />
      )}
    </main>
  );
}
