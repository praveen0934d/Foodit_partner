class MenuItem {
  final String id;
  final String name;
  final double price;
  final bool isVeg;
  final bool isAvailable;
  final int availableQty;
  final String? imageUrl; 
  final String? category; 

  MenuItem({
    required this.id, required this.name, required this.price,
    required this.isVeg, required this.isAvailable, required this.availableQty, this.imageUrl,
    this.category, 
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    String? parsedImage;
    if (json['images'] != null && (json['images'] as List).isNotEmpty) {
      parsedImage = json['images'][0];
    }

    return MenuItem(
      id: json['id'],
      name: json['name'],
      price: double.parse(json['price'].toString()),
      isVeg: json['is_veg'] ?? false,
      isAvailable: json['is_available'] ?? true,
      availableQty: json['inventory'] != null ? json['inventory']['available_qty'] ?? 0 : 0,
      imageUrl: parsedImage,
      category: json['category'], 
    );
  }

  MenuItem copyWith({bool? isAvailable, int? availableQty, String? name, double? price, bool? isVeg, String? imageUrl, String? category}) {
    return MenuItem(
      id: id, 
      name: name ?? this.name, 
      price: price ?? this.price, 
      isVeg: isVeg ?? this.isVeg,
      isAvailable: isAvailable ?? this.isAvailable,
      availableQty: availableQty ?? this.availableQty,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category, 
    );
  }
}

class Restaurant {
  final String id;
  final String name;
  final String description;
  final double rating;
  final bool isOpen;
  final List<MenuItem> menuItems;
  final String? phone;
  final double minOrderAmount;
  final List<dynamic>? images; 

  Restaurant({
    required this.id, required this.name, required this.description,
    required this.rating, required this.isOpen, required this.menuItems,this.phone, required this.minOrderAmount,
    this.images, 
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    var list = json['available_menu_items'] as List? ?? json['menu_items'] as List? ?? [];
    List<MenuItem> menuList = list.map((i) => MenuItem.fromJson(i)).toList();

    return Restaurant(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? 'Campus Favorite',
      rating: json['rating'] != null ? double.parse(json['rating'].toString()) : 4.0,
      isOpen: json['is_open'] ?? false,
      menuItems: menuList,
      phone: json['phone'],
      minOrderAmount: (json['min_order_amount'] ?? 0).toDouble(), 
      images: json['images'] as List<dynamic>?, 
    );
  }

  Restaurant copyWith({
    bool? isOpen, 
    List<MenuItem>? menuItems,
    String? name,
    String? description,
    String? phone,
    double? minOrderAmount,
    List<dynamic>? images,
  }) {
    return Restaurant(
      id: this.id, 
      name: name ?? this.name, 
      description: description ?? this.description, 
      rating: this.rating,
      isOpen: isOpen ?? this.isOpen,
      menuItems: menuItems ?? this.menuItems,
      phone: phone ?? this.phone,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      images: images ?? this.images, 
    );
  }
}