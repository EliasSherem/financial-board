export interface ExpenseSubcategory {
  id: number;
  name: string;
  icon: string | null;
}

export interface ExpenseCategory {
  id: number;
  name: string;
  icon: string | null;
  subcategories: ExpenseSubcategory[];
}

export type CategorySelectionValue = {
  category: ExpenseCategory | null;
  subcategory: ExpenseSubcategory | null;
};
