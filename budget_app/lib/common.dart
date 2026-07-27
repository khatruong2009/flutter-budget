import 'package:flutter/cupertino.dart';

/// Serializable icon names available to custom categories.
const Map<String, IconData> categoryIconRegistry = {
  'square_grid_2x2': CupertinoIcons.square_grid_2x2,
  'asterisk_circle': CupertinoIcons.asterisk_circle,
  'cart': CupertinoIcons.cart,
  'house': CupertinoIcons.house,
  'car': CupertinoIcons.car_detailed,
  'airplane': CupertinoIcons.airplane,
  'bag': CupertinoIcons.bag,
  'gift': CupertinoIcons.gift,
  'heart': CupertinoIcons.heart,
  'film': CupertinoIcons.film,
  'paw': CupertinoIcons.paw,
  'people': CupertinoIcons.person_2,
  'money': CupertinoIcons.money_dollar,
  'chart': CupertinoIcons.chart_bar,
  'book': CupertinoIcons.book,
  'phone': CupertinoIcons.device_phone_portrait,
  'wrench': CupertinoIcons.hammer,
  'leaf': CupertinoIcons.leaf_arrow_circlepath,
};

/// These maps remain the compatibility surface for transactions, reports, and
/// imports that store category names. `CategoryProvider` updates them after
/// loading persisted definitions.
final Map<String, IconData> expenseCategories = {
  'General': categoryIconRegistry['square_grid_2x2']!,
  'Eating Out': categoryIconRegistry['asterisk_circle']!,
  'Groceries': categoryIconRegistry['cart']!,
  'Housing': categoryIconRegistry['house']!,
  'Transportation': categoryIconRegistry['car']!,
  'Travel': categoryIconRegistry['airplane']!,
  'Clothing': categoryIconRegistry['bag']!,
  'Gift': categoryIconRegistry['gift']!,
  'Health': categoryIconRegistry['heart']!,
  'Entertainment': categoryIconRegistry['film']!,
  'Pets': categoryIconRegistry['paw']!,
  'Family': categoryIconRegistry['people']!,
  'Loan Payment': categoryIconRegistry['money']!,
};

final Map<String, IconData> incomeCategories = {
  'Salary': categoryIconRegistry['money']!,
  'Investment': categoryIconRegistry['chart']!,
  'Gift': categoryIconRegistry['gift']!,
  'Other': categoryIconRegistry['square_grid_2x2']!,
};
