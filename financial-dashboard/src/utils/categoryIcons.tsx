import type { LucideIcon } from 'lucide-react';
import {
  Baby,
  BriefcaseBusiness,
  Car,
  Clapperboard,
  Coffee,
  Dog,
  Dumbbell,
  Gift,
  GraduationCap,
  HeartPulse,
  Home,
  Music,
  PawPrint,
  PiggyBank,
  Plane,
  Sandwich,
  Search,
  ShoppingCart,
  Shirt,
  Sparkles,
  Stethoscope,
  Tv,
  Utensils,
  UtensilsCrossed,
  Zap,
} from 'lucide-react';

export type CategoryIconOption = {
  key: string;
  label: string;
  Icon: LucideIcon;
};

const OPTION_LIST: CategoryIconOption[] = [
  { key: 'shopping_cart', label: 'Shopping', Icon: ShoppingCart },
  { key: 'fastfood', label: 'Food & Dining', Icon: UtensilsCrossed },
  { key: 'home', label: 'Home', Icon: Home },
  { key: 'directions_car', label: 'Transportation', Icon: Car },
  { key: 'local_cafe', label: 'Coffee', Icon: Coffee },
  { key: 'subscriptions', label: 'Subscriptions', Icon: Tv },
  { key: 'favorite', label: 'Health', Icon: HeartPulse },
  { key: 'medical_services', label: 'Medical', Icon: Stethoscope },
  { key: 'exercise', label: 'Fitness', Icon: Dumbbell },
  { key: 'school', label: 'Education', Icon: GraduationCap },
  { key: 'work', label: 'Work', Icon: BriefcaseBusiness },
  { key: 'travel', label: 'Travel', Icon: Plane },
  { key: 'entertainment', label: 'Entertainment', Icon: Clapperboard },
  { key: 'music', label: 'Music', Icon: Music },
  { key: 'pets', label: 'Pets', Icon: PawPrint },
  { key: 'child_care', label: 'Family', Icon: Baby },
  { key: 'gift', label: 'Gifts', Icon: Gift },
  { key: 'savings', label: 'Savings', Icon: PiggyBank },
  { key: 'restaurant', label: 'Restaurants', Icon: Utensils },
  { key: 'laundry', label: 'Services', Icon: Shirt },
  { key: 'bolt', label: 'Utilities', Icon: Zap },
  { key: 'groceries', label: 'Groceries', Icon: ShoppingCart },
  { key: 'snacks', label: 'Snacks', Icon: Sandwich },
  { key: 'vet', label: 'Veterinary', Icon: Dog },
  { key: 'services', label: 'Household', Icon: Sparkles },
];

const iconMap: Record<string, LucideIcon> = OPTION_LIST.reduce((acc, option) => {
  acc[option.key] = option.Icon;
  return acc;
}, {} as Record<string, LucideIcon>);

const defaultIcon: LucideIcon = Search;

export const CATEGORY_ICON_OPTIONS: CategoryIconOption[] = OPTION_LIST;

export function iconForCategory(key?: string | null): LucideIcon {
  if (!key) return defaultIcon;
  return iconMap[key] ?? defaultIcon;
}
