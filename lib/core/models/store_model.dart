import 'package:flutter/material.dart';

class StoreModel {
  const StoreModel({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.backgroundColor,
    required this.chipActiveColor,
    required this.textColor,
    required this.categories,
  });

  final String id;
  final String label;
  final String subtitle;
  final Color backgroundColor;
  final Color chipActiveColor;
  final Color textColor;
  final List<String> categories;
}

const List<StoreModel> appStores = <StoreModel>[
  StoreModel(
    id: 'zepto',
    label: 'Zepto',
    subtitle: '6 mins',
    backgroundColor: Color(0xFF88D4FE),
    chipActiveColor: Color(0xFF1A3461),
    textColor: Colors.black,
    categories: ['Fruits & Veg', 'Dairy', 'Snacks', 'Beverages', 'Rice', 'Bread'],
  ),
  StoreModel(
    id: 'off_zone',
    label: '50% OFF ZONE',
    subtitle: 'Mega deals',
    backgroundColor: Color(0xFFFF6B35),
    chipActiveColor: Color(0xFFCC3A00),
    textColor: Colors.white,
    categories: ['Flash Sale', 'Combos', 'Clearance', 'Buy 1 Get 1', 'Bulk Buy'],
  ),
  StoreModel(
    id: 'super_mall',
    label: 'Super Mall',
    subtitle: 'All in one store',
    backgroundColor: Color(0xFFD02428),
    chipActiveColor: Color(0xFFA81C1F),
    textColor: Colors.white,
    categories: ['Electronics', 'Fashion', 'Home', 'Beauty', 'Sports'],
  ),
  StoreModel(
    id: 'cafe',
    label: 'Cafe',
    subtitle: 'Hot & fresh',
    backgroundColor: Color(0xFF92400E),
    chipActiveColor: Color(0xFF6B2E00),
    textColor: Colors.white,
    categories: ['Coffee', 'Tea', 'Snacks', 'Meals', 'Desserts'],
  ),
];
