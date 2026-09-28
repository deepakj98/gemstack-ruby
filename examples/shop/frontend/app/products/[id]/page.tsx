"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ProductCard } from "@/components/products/ProductCard";
import { useProduct, useDeleteProduct } from "@/lib/queries/products";

export default function ProductPage() {
  const { id } = useParams<{ id: string }>();
  const product = useProduct(id);
  const router = useRouter();
  const remove = useDeleteProduct();

  async function handleDelete() {
    if (!window.confirm("Delete this product?")) return;
    await remove.mutateAsync(id);
    router.push("/products");
  }

  return (
    <main className="page">
      <p>
        <Link href="/products">← Products</Link>
      </p>
      {product.isPending && <p className="muted">Loading…</p>}
      {product.isError && <p className="form-error">{product.error.message}</p>}
      {product.data && (
        <>
          <h1>Product #{product.data.id}</h1>
          <ProductCard product={product.data} />
          <div className="actions">
            <Link className="button" href={`/products/${id}/edit`}>
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
