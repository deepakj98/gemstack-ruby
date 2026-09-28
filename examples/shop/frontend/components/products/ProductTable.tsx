import Link from "next/link";
import { display } from "@/lib/format";
import type { Product } from "@/lib/api/generated";

export function ProductTable({ products }: { products: Product[] }) {
  if (products.length === 0) return <p className="muted">No products yet.</p>;

  return (
    <table className="table">
      <thead>
        <tr>
          <th>Name</th>
          <th>Price</th>
          <th>Description</th>
          <th>Sku</th>
          <th aria-label="Actions" />
        </tr>
      </thead>
      <tbody>
        {products.map((product) => (
          <tr key={product.id}>
            <td>{display(product.name)}</td>
            <td>{display(product.price)}</td>
            <td>{display(product.description)}</td>
            <td>{display(product.sku)}</td>
            <td>
              <Link href={`/products/${product.id}`}>View</Link>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
