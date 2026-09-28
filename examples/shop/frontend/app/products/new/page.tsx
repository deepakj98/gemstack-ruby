"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { ProductForm } from "@/components/products/ProductForm";
import { useCreateProduct } from "@/lib/queries/products";

export default function NewProductPage() {
  const router = useRouter();
  const create = useCreateProduct();

  return (
    <main className="page">
      <p>
        <Link href="/products">← Products</Link>
      </p>
      <h1>New product</h1>
      <ProductForm
        submitLabel="Create product"
        onSubmit={async (input) => {
          const product = await create.mutateAsync(input);
          router.push(`/products/${product.id}`);
        }}
      />
    </main>
  );
}
