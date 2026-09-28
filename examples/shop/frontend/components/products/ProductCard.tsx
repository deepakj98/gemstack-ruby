import { display } from "@/lib/format";
import type { Product } from "@/lib/api/generated";

export function ProductCard({ product }: { product: Product }) {
  return (
    <dl className="card">
      <dt>Name</dt>
      <dd>{display(product.name)}</dd>
      <dt>Price</dt>
      <dd>{display(product.price)}</dd>
      <dt>Description</dt>
      <dd>{display(product.description)}</dd>
      <dt>Sku</dt>
      <dd>{display(product.sku)}</dd>
      <dt>Category</dt>
      <dd>{display(product.category_id)}</dd>
      <dt>Active</dt>
      <dd>{display(product.active)}</dd>
      <dt>Created</dt>
      <dd>{new Date(product.created_at).toLocaleString()}</dd>
    </dl>
  );
}
