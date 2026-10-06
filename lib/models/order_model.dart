class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;

  OrderItem({required this.id, required this.name, required this.quantity, required this.price});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      // Handles potential differences in how Laravel nests the item details
      id: json['id'] ?? json['order_item_id'] ?? '', 
      name: json['menu_item']?['name'] ?? json['name'] ?? 'Unknown Item',
      quantity: json['quantity'] ?? 1,
      price: double.parse(json['price']?.toString() ?? '0'),
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final double totalAmount;
  final String studentName;
  final String studentPhone;
  final String? specialInstructions;
  final double discountAmount;
  final String? couponCode;
  final List<OrderItem> items;
  final String? deliveryAgentName;
  final String? deliveryAgentPhone;

  Order({
    required this.id, required this.orderNumber, required this.status, required this.totalAmount,
    required this.studentName, required this.studentPhone, this.specialInstructions, required this.items, this.deliveryAgentName,
    this.deliveryAgentPhone, this.discountAmount = 0.0, this.couponCode,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemList = json['items'] as List? ?? [];
    return Order(
      id: json['id'],
      orderNumber: json['order_number'],
      status: json['status'],
      totalAmount: double.parse(json['total_amount']?.toString() ?? '0'),
      studentName: json['student']?['name'] ?? 'Student',
      studentPhone: json['student']?['phone'] ?? '',
      specialInstructions: json['special_instructions'],
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      couponCode: json['coupon_code']?.toString() ?? json['coupon']?.toString(),
      items: itemList.map((i) => OrderItem.fromJson(i)).toList(),
      deliveryAgentName: json['delivery_agent']?['name'],
      deliveryAgentPhone: json['delivery_agent']?['phone'],
    );
  }
}