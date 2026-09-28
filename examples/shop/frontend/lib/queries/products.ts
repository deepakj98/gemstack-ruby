"use client";

// TanStack Query hooks for products, built on the generated API client.
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { products } from "@/lib/api/generated";
import type { Product, ProductInput, ProductUpdateInput } from "@/lib/api/generated";

export const productKeys = {
  all: ["products"] as const,
  detail: (id: string | number) => ["products", String(id)] as const,
};

export function useProducts(page = 1) {
  return useQuery({
    queryKey: [...productKeys.all, "page", page],
    queryFn: () => products.list({ page }),
    placeholderData: keepPreviousData, // keep the current page visible while the next one loads
  });
}

export function useProduct(id: string | number) {
  return useQuery({ queryKey: productKeys.detail(id), queryFn: () => products.get(id) });
}

export function useCreateProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: ProductInput) => products.create(data),
    onSuccess: (product: Product) => {
      queryClient.setQueryData(productKeys.detail(product.id), product);
      return queryClient.invalidateQueries({ queryKey: productKeys.all });
    },
  });
}

export function useUpdateProduct(id: string | number) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: ProductUpdateInput) => products.update(id, data),
    onSuccess: (product: Product) => {
      queryClient.setQueryData(productKeys.detail(id), product);
      return queryClient.invalidateQueries({ queryKey: productKeys.all });
    },
  });
}

export function useDeleteProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string | number) => products.delete(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: productKeys.all }),
  });
}
