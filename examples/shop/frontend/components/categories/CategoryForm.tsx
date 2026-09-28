"use client";

import { useState, type ChangeEvent, type FormEvent } from "react";
import { ApiError } from "@/lib/gemstack/client";
import type { FieldErrors } from "@/lib/format";
import type { Category, CategoryInput } from "@/lib/api/generated";

type Values = {
  name: string;
};

function initialValues(record?: Category): Values {
  return {
    name: record?.name ?? "",
  };
}

// Form values are strings; the API validates and coerces them (see Category.input_schema).
function toInput(values: Values): CategoryInput {
  return {
    name: values.name,
  } as unknown as CategoryInput;
}

export function CategoryForm({
  category,
  submitLabel,
  onSubmit,
}: {
  category?: Category;
  submitLabel: string;
  onSubmit: (input: CategoryInput) => Promise<unknown>;
}) {
  const [values, setValues] = useState<Values>(() => initialValues(category));
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
      <button className="button" type="submit" disabled={pending}>
        {pending ? "Saving…" : submitLabel}
      </button>
    </form>
  );
}
