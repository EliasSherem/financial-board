import 'package:flutter/material.dart';

class CategoryIconOption {
  final String key;
  final IconData icon;
  final String label;

  const CategoryIconOption({
    required this.key,
    required this.icon,
    required this.label,
  });
}

const List<CategoryIconOption> kCategoryIconOptions = [
  CategoryIconOption(key: 'shopping_cart', icon: Icons.shopping_cart_outlined, label: 'Shopping'),
  CategoryIconOption(key: 'fastfood', icon: Icons.fastfood_outlined, label: 'Food & Dining'),
  CategoryIconOption(key: 'home', icon: Icons.home_outlined, label: 'Home'),
  CategoryIconOption(key: 'directions_car', icon: Icons.directions_car_outlined, label: 'Transportation'),
  CategoryIconOption(key: 'local_cafe', icon: Icons.local_cafe_outlined, label: 'Coffee'),
  CategoryIconOption(key: 'subscriptions', icon: Icons.subscriptions_outlined, label: 'Subscriptions'),
  CategoryIconOption(key: 'favorite', icon: Icons.favorite_border, label: 'Health'),
  CategoryIconOption(key: 'medical_services', icon: Icons.medical_services_outlined, label: 'Medical'),
  CategoryIconOption(key: 'exercise', icon: Icons.fitness_center_outlined, label: 'Fitness'),
  CategoryIconOption(key: 'school', icon: Icons.school_outlined, label: 'Education'),
  CategoryIconOption(key: 'work', icon: Icons.work_outline, label: 'Work'),
  CategoryIconOption(key: 'travel', icon: Icons.flight_takeoff_outlined, label: 'Travel'),
  CategoryIconOption(key: 'entertainment', icon: Icons.movie_outlined, label: 'Entertainment'),
  CategoryIconOption(key: 'music', icon: Icons.music_note_outlined, label: 'Music'),
  CategoryIconOption(key: 'pets', icon: Icons.pets_outlined, label: 'Pets'),
  CategoryIconOption(key: 'child_care', icon: Icons.child_friendly_outlined, label: 'Family'),
  CategoryIconOption(key: 'gift', icon: Icons.card_giftcard_outlined, label: 'Gifts'),
  CategoryIconOption(key: 'savings', icon: Icons.savings_outlined, label: 'Savings'),
  CategoryIconOption(key: 'restaurant', icon: Icons.restaurant_outlined, label: 'Restaurants'),
  CategoryIconOption(key: 'laundry', icon: Icons.local_laundry_service_outlined, label: 'Services'),
  CategoryIconOption(key: 'bolt', icon: Icons.bolt_outlined, label: 'Utilities'),
];

CategoryIconOption categoryIconByKey(String? key) {
  if (key == null || key.isEmpty) return kCategoryIconOptions.first;
  return kCategoryIconOptions.firstWhere(
    (option) => option.key == key,
    orElse: () => kCategoryIconOptions.first,
  );
}

IconData iconDataFromKey(String? key) => categoryIconByKey(key).icon;
