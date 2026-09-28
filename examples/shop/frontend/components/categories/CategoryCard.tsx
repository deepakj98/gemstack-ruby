import { display } from "@/lib/format";
import type { Category } from "@/lib/api/generated";

export function CategoryCard({ category }: { category: Category }) {
  return (
    <dl className="card">
      <dt>Name</dt>
      <dd>{display(category.name)}</dd>
      <dt>Created</dt>
      <dd>{new Date(category.created_at).toLocaleString()}</dd>
    </dl>
  );
}
