class ProductModel {
  int? id;
  String name;
  double calories;
  double proteins;
  double carbs;
  double fats;
  double sugar;
  double? fiber;
  String? countryOrigin;
  String? category;
  String? barcode;
  String? imageUrl;
  DateTime? createdAt;
  DateTime? updatedAt;

  ProductModel({
    this.id,
    required this.name,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.sugar,
    this.fiber,
    this.countryOrigin,
    this.category,
    this.barcode,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  ProductModel.create({
    required this.name,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.sugar,
    this.fiber,
    this.countryOrigin,
    this.category,
    this.barcode,
    this.imageUrl,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'proteins': proteins,
      'carbs': carbs,
      'fats': fats,
      'sugar': sugar,
      'fiber': fiber,
      'countryOrigin': countryOrigin,
      'category': category,
      'barcode': barcode,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      calories: (map['calories'] as num).toDouble(),
      proteins: (map['proteins'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fats: (map['fats'] as num).toDouble(),
      sugar: (map['sugar'] as num).toDouble(),
      fiber: map['fiber'] != null ? (map['fiber'] as num).toDouble() : null,
      countryOrigin: map['countryOrigin'] as String?,
      category: map['category'] as String?,
      barcode: map['barcode'] as String?,
      imageUrl: map['imageUrl'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
    );
  }

  ProductModel copyWith({
    int? id,
    String? name,
    double? calories,
    double? proteins,
    double? carbs,
    double? fats,
    double? sugar,
    double? fiber,
    String? countryOrigin,
    String? category,
    String? barcode,
    String? imageUrl,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteins: proteins ?? this.proteins,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      sugar: sugar ?? this.sugar,
      fiber: fiber ?? this.fiber,
      countryOrigin: countryOrigin ?? this.countryOrigin,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
