import 'package:flutter/material.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

class HomeProductImagePalette {
  const HomeProductImagePalette({
    required this.gradient,
    required this.fallbackColor,
  });

  final LinearGradient gradient;
  final Color fallbackColor;
}

const _freshProduceImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF6F0DD),
      Color(0xFFDCEFE3),
    ],
  ),
  fallbackColor: Color(0xFFE7EFE6),
);

const _redProduceImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF7EEE8),
      Color(0xFFEADFE6),
    ],
  ),
  fallbackColor: Color(0xFFF0E6EA),
);

const _dairyImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF8EED8),
      Color(0xFFDDEDFC),
    ],
  ),
  fallbackColor: Color(0xFFEAF0F4),
);

const _snackImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF5E4CC),
      Color(0xFFF8F0DF),
    ],
  ),
  fallbackColor: Color(0xFFF3E8D8),
);

const _beverageImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFDFF2F8),
      Color(0xFFEAF3FF),
    ],
  ),
  fallbackColor: Color(0xFFE5F0F8),
);

const _neutralImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFEFF1F5),
      Color(0xFFF8F9FB),
    ],
  ),
  fallbackColor: Color(0xFFF1F3F6),
);

const _freshRetailRedProduceImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF8F1ED),
      Color(0xFFFDF8F3),
    ],
  ),
  fallbackColor: Color(0xFFF7F1ED),
);

const _freshRetailDairyImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF9F8F1),
      Color(0xFFEAF6FB),
    ],
  ),
  fallbackColor: Color(0xFFF3F6F0),
);

const _freshRetailBeverageImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF1F8FD),
      Color(0xFFEAF3FB),
    ],
  ),
  fallbackColor: Color(0xFFE9F3FA),
);

const _freshRetailSnackImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF8F2E5),
      Color(0xFFFBF8F1),
    ],
  ),
  fallbackColor: Color(0xFFF5EEDF),
);

const _freshRetailProduceImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF6FAEF),
      Color(0xFFEFF6E9),
    ],
  ),
  fallbackColor: Color(0xFFF2F7EA),
);

const _freshRetailNeutralImagePalette = HomeProductImagePalette(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF3F6F0),
      Color(0xFFF9FAF5),
    ],
  ),
  fallbackColor: Color(0xFFF4F7F1),
);

enum PaletteVariant { standard, fresh }

HomeProductImagePalette productImagePalette(
  ProductEntity product, {
  PaletteVariant variant = PaletteVariant.standard,
}) {
  final signals = <String>[
    product.categoryName ?? '',
    product.categoryId ?? '',
    product.name,
    ...product.tags,
  ].join(' ').toLowerCase();
  final isFreshVariant = variant == PaletteVariant.fresh;
  final redProducePalette = isFreshVariant
      ? _freshRetailRedProduceImagePalette
      : _redProduceImagePalette;
  final dairyPalette =
      isFreshVariant ? _freshRetailDairyImagePalette : _dairyImagePalette;
  final beveragePalette =
      isFreshVariant ? _freshRetailBeverageImagePalette : _beverageImagePalette;
  final snackPalette =
      isFreshVariant ? _freshRetailSnackImagePalette : _snackImagePalette;
  final freshProducePalette = isFreshVariant
      ? _freshRetailProduceImagePalette
      : _freshProduceImagePalette;
  final neutralPalette =
      isFreshVariant ? _freshRetailNeutralImagePalette : _neutralImagePalette;

  if (matchesAnyKeyword(signals, const <String>[
    'tomato',
    'apple',
    'onion',
    'pomegranate',
    'beetroot',
    'strawberry',
    'cherry',
  ])) {
    return redProducePalette;
  }

  if (matchesAnyKeyword(signals, const <String>[
    'milk',
    'paneer',
    'curd',
    'cheese',
    'butter',
    'yogurt',
    'yoghurt',
    'lassi',
    'ice cream',
    'vanilla',
    'dairy',
  ])) {
    return dairyPalette;
  }

  if (matchesAnyKeyword(signals, const <String>[
    'juice',
    'cola',
    'coke',
    'coca',
    'drink',
    'beverage',
    'soft drink',
    'soda',
    'mango',
    'pressery',
    'raw',
  ])) {
    return beveragePalette;
  }

  if (matchesAnyKeyword(signals, const <String>[
    'chips',
    'snack',
    'biscuit',
    'cookie',
    'cookies',
    'bakery',
    'bread',
    'cake',
    'egg',
    'eggs',
    'namkeen',
    'wafer',
    'lays',
  ])) {
    return snackPalette;
  }

  if (matchesAnyKeyword(signals, const <String>[
    'fruit',
    'fruits',
    'veg',
    'veggie',
    'vegetable',
    'leafy',
    'herb',
    'spinach',
    'palak',
    'banana',
    'potato',
    'greens',
    'fresh',
  ])) {
    return freshProducePalette;
  }

  return neutralPalette;
}

bool matchesAnyKeyword(String source, List<String> keywords) {
  return keywords.any(source.contains);
}
