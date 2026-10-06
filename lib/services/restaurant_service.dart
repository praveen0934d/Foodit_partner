import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:foodit_partner/models/order_model.dart';
import 'package:foodit_partner/models/blocked_student_model.dart';
import '../models/restaurant_model.dart';
import 'api_client.dart';

class RestaurantService {

  Future<Restaurant?> getMyRestaurant() async {
    debugPrint('🔍 [GetMyRestaurant] GET /restaurant/profile');
    final response = await ApiClient.get('/restaurant/profile');

    debugPrint('🔍 [GetMyRestaurant] Status: ${response.statusCode}');
    debugPrint('🔍 [GetMyRestaurant] Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Restaurant.fromJson(data['restaurant']); 
    } else if (response.statusCode == 404 || response.statusCode == 403) {
      // 404 = no restaurant, 403 = account unlinked — both mean "no restaurant for this user"
      return null; 
    } else {
      throw Exception('Failed to load restaurant (${response.statusCode})');
    }
  }

  Future<bool?> toggleRestaurantStatus(String id) async {
    final url = '/restaurants/$id/toggle-open';
    debugPrint('🔍 [ToggleStatus] PUT $url');
    
    final response = await ApiClient.put(url);
    
    debugPrint('🔍 [ToggleStatus] Status: ${response.statusCode}');
    debugPrint('🔍 [ToggleStatus] Body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('is_open')) {
          return data['is_open'] == true || data['is_open'] == 1;
        }
        if (data is Map && data.containsKey('data') && data['data'].containsKey('is_open')) {
          return data['data']['is_open'] == true || data['data']['is_open'] == 1;
        }
      } catch (e) {
        debugPrint('🔍 [ToggleStatus] JSON Parse error: $e');
      }
      return null; // Signals to the BLoC that it succeeded, but we need to guess the new state
    }
    throw Exception('Failed to toggle status: ${response.body}');
  }

  Future<bool> toggleMenuItemStatus(String restaurantId, String itemId) async {
    final response = await ApiClient.put('/restaurants/$restaurantId/menu/$itemId/toggle');
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['is_available']; 
    }
    throw Exception('Failed to toggle menu item');
  }

  Future<MenuItem> addMenuItem(String restaurantId, Map<String, dynamic> data) async {
    final response = await ApiClient.post('/restaurants/$restaurantId/menu', body: data);

    if (response.statusCode == 201) {
      return MenuItem.fromJson(jsonDecode(response.body)['menu_item']);
    } else if (response.statusCode == 422) {
      final errors = jsonDecode(response.body)['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) throw Exception(errors.values.first[0]);
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to add item');
  }

  Future<MenuItem> updateMenuItem(String restaurantId, String itemId, Map<String, dynamic> data) async {
    final response = await ApiClient.put('/restaurants/$restaurantId/menu/$itemId', body: data);

    if (response.statusCode == 200) {
      return MenuItem.fromJson(jsonDecode(response.body)['menu_item']);
    } else if (response.statusCode == 422) {
      final errors = jsonDecode(response.body)['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) throw Exception(errors.values.first[0]);
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to update item');
  }

  Future<void> deleteMenuItem(String restaurantId, String itemId) async {
    final response = await ApiClient.delete('/restaurants/$restaurantId/menu/$itemId');

    if (response.statusCode != 200) {
      throw Exception('Failed to delete menu item');
    }
  }

  Future<List<Order>> getRestaurantOrders({String status = 'active', String? date}) async {
    String url = '/restaurant/orders?status=$status';
    if (date != null && date.isNotEmpty) {
      url += '&date=$date';
    }

    final response = await ApiClient.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List items = data['orders']?['data'] ?? []; 
      return items.map((json) => Order.fromJson(json)).toList();
    }
    throw Exception('Failed to load orders');
  }

  Future<void> rejectOrder(String orderId, String reason) async {
    final response = await ApiClient.put('/orders/$orderId/reject', body: {"reason": reason});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to reject order');
    }
  }

  Future<void> prepareOrder(String orderId, List<Map<String, dynamic>> itemDecisions) async {
    final response = await ApiClient.put('/orders/$orderId/prepare', body: {"items": itemDecisions});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to accept order');
    }
  }

  Future<void> assignDeliveryAgent(String agentId, List<String> orderIds) async {
    final response = await ApiClient.put('/orders/assign-agent', body: {"delivery_agent_id": agentId, "order_ids": orderIds});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to assign agent');
    }
  }

  Future<List<Map<String, dynamic>>> getRestaurantDeliveryAgents(String restaurantId) async {
    final response = await ApiClient.get('/restaurants/$restaurantId/delivery-agents');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['agents'] ?? []);
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to load delivery agents');
  }

  Future<String> getUserRole() async {
    final response = await ApiClient.get('/auth/profile');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['user']?['role'] ?? 'Unknown';
    }
    throw Exception('Failed to load user profile');
  }

  Future<void> updateRestaurant(String id, Map<String, dynamic> data) async {
    final response = await ApiClient.put('/restaurants/$id', body: data);
    
    if (response.statusCode != 200) {
      try {
        final errorData = jsonDecode(response.body);
        final message = errorData['message'] ?? errorData['error'] ?? 'Failed to update restaurant';
        throw Exception(message);
      } catch (_) {
        throw Exception('Failed to update restaurant (Error Code: ${response.statusCode})');
      }
    }
  }

  Future<List<BlockedStudent>> getBlockedStudents(String restaurantId) async {
    final url = '/restaurants/$restaurantId/blocked-users';
    debugPrint('🔍 [BlockedStudents] GET $url');
    final response = await ApiClient.get(url);

    debugPrint('🔍 [BlockedStudents] Status: ${response.statusCode}');
    debugPrint('🔍 [BlockedStudents] Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List items = data['blocked_users'] ?? data['blocked_students'] ?? data['data'] ?? [];
      return items.map((json) => BlockedStudent.fromJson(json)).toList();
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to load blocked students');
  }

  Future<Map<String, dynamic>> toggleBlockStudent(String restaurantId, String studentId, {String? reason}) async {
    final response = await ApiClient.post(
      '/restaurants/$restaurantId/block/toggle/$studentId',
      body: {if (reason != null) 'reason': reason},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to toggle student block status');
  }
} 