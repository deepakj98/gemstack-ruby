"use client";

import { useState, type ChangeEvent, type FormEvent } from "react";
import { ApiError } from "@/lib/gemstack/client";
import type { FieldErrors } from "@/lib/format";
import type { Product, ProductInput } from "@/lib/api/generated";

type Values = {
  name: string;
  price: string;
  description: string;
  sku: string;
  category_id: string;
  active: boolean;
};

function initialValues(record?: Product): Values {
  return {
    name: record?.name ?? "",
    price: record?.price ?? "",
    description: record?.description ?? "",
    sku: record?.sku ?? "",
    category_id: String(record?.category_id ?? ""),
    active: record?.active ?? false,
  };
}

// Form values are strings; the API validates and coerces them (see Product.input_schema).
function toInput(values: Values): ProductInput {
  return {
    name: values.name,
    price: values.price,
    description: values.description === "" ? null : values.description,
    sku: values.sku,
    category_id: values.category_id === "" ? "" : Number(values.category_id),
    active: values.active,
  } as unknown as ProductInput;
}

export function ProductForm({
  product,
  submitLabel,
  onSubmit,
}: {
  product?: Product;
  submitLabel: string;
  onSubmit: (input: ProductInput) => Promise<unknown>;
}) {
  const [values, setValues] = useState<Values>(() => initialValues(product));
  const [errors, setErrors] = useState<FieldErrors>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  const set = (key: keyof Values) => (event: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const target = event.target;
    const value = target instanceof HTMLInputElement && target.type === "checkbox" ? target.checked : target.value;
    setValues((current) => ({ ...current, [key]: value }));
  };

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setErrors({});
    setFormError(null);
    try {
      await onSubmit(toInput(values));
    } catch (error) {
      if (error instanceof ApiError) {
        setErrors(error.errors);
        setFormError(Object.keys(error.errors).length ? null : error.message);
      } else {
        setFormError("Something went wrong. Please try again.");
      }
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="form" onSubmit={handleSubmit} noValidate>
      {formError && <p className="form-error" role="alert">{formError}</p>}
      <div className="field">
        <label htmlFor="name">Name</label>
        <input id="name" name="name" type="text" value={values.name} onChange={set("name")} required />
        {errors.name?.map((message) => (
          <p key={message} className="field-error">{message}</p>
        ))}
      </div>
      <div className="field">
        <label htmlFor="price">Price</label>
        <input id="price" name="price" type="text" inputMode="decimal" value={values.price} onChange={set("price")} required />
        {errors.price?.map((message) => (
          <p key={message} className="field-error">{message}</p>
        ))}
      </div>
      <div className="field">
        <label htmlFor="description">Description</label>
        <textarea id="description" name="description" rows={4} value={values.description} onChange={set("description")} />
        {errors.description?.map((message) => (
          <p key={message} className="field-error">{message}</p>
        ))}
      </div>
      <div className="field">
        <label htmlFor="sku">Sku</label>
        <input id="sku" name="sku" type="text" value={values.sku} onChange={set("sku")} required />
        {errors.sku?.map((message) => (
          <p key={message} className="field-error">{message}</p>
        ))}
      </div>
      <div className="field">
        <label htmlFor="category_id">Category</label>
        <input id="category_id" name="category_id" type="number" step="1" value={values.category_id} onChange={set("category_id")} required />
        {errors.category_id?.map((message) => (
          <p key={message} className="field-error">{message}</p>
        ))}
      </div>
      <div className="field">
        <label htmlFor="active">Active</label>
        <input id="active" name="active" type="checkbox" checked={values.active} onChange={set("active")} />
        {errors.active?.map((message) => (
          <p key={message} className="field-error">{message}</p>
        ))}
      </div>
      <button className="button" type="submit" disabled={pending}>
        {pending ? "Saving…" : submitLabel}
      </button>
    </form>
  );
}
