import Link from "next/link";
import { display } from "@/lib/format";
import type { Category } from "@/lib/api/generated";

export function CategoryTable({ categories }: { categories: Category[] }) {
  if (categories.length === 0) return <p className="muted">No categories yet.</p>;

  return (
    <table className="table">
      <thead>
        <tr>
          <th>Name</th>
          <th aria-label="Actions" />
        </tr>
      </thead>
      <tbody>
        {categories.map((category) => (
          <tr key={category.id}>
            <td>{display(category.name)}</td>
            <td>
              <Link href={`/categories/${category.id}`}>View</Link>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
