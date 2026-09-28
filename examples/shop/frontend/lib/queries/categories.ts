"use client";

// TanStack Query hooks for categories, built on the generated API client.
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { categories } from "@/lib/api/generated";
import type { Category, CategoryInput, CategoryUpdateInput } from "@/lib/api/generated";

export const categoryKeys = {
  all: ["categories"] as const,
  detail: (id: string | number) => ["categories", String(id)] as const,
};

export function useCategories() {
  return useQuery({ queryKey: categoryKeys.all, queryFn: () => categories.list() });
}

export function useCategory(id: string | number) {
  return useQuery({ queryKey: categoryKeys.detail(id), queryFn: () => categories.get(id) });
}

export function useCreateCategory() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: CategoryInput) => categories.create(data),
    onSuccess: (category: Category) => {
      queryClient.setQueryData(categoryKeys.detail(category.id), category);
      return queryClient.invalidateQueries({ queryKey: categoryKeys.all });
    },
  });
}

export function useUpdateCategory(id: string | number) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: CategoryUpdateInput) => categories.update(id, data),
    onSuccess: (category: Category) => {
      queryClient.setQueryData(categoryKeys.detail(id), category);
      return queryClient.invalidateQueries({ queryKey: categoryKeys.all });
    },
  });
}

export function useDeleteCategory() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string | number) => categories.delete(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: categoryKeys.all }),
  });
}
