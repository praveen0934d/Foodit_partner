import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../models/order_model.dart';
import '../../services/restaurant_service.dart';
import '../../services/order_alarm_service.dart';

abstract class OrderState {}
class OrdersLoading extends OrderState {}
class OrdersLoaded extends OrderState {
  final List<Order> pendingOrders;
  final List<Order> preparingOrders;
  final List<Order> outForDeliveryOrders;
  final List<Order> historyOrders;

  OrdersLoaded(this.pendingOrders, this.preparingOrders, this.outForDeliveryOrders, this.historyOrders);
}
class OrdersError extends OrderState {
  final String message;
  OrdersError(this.message);
}

abstract class OrderEvent {}
class LoadActiveOrders extends OrderEvent {}

class AcceptOrderRequested extends OrderEvent {
  final Order order;
  AcceptOrderRequested(this.order);
}

class RejectOrderRequested extends OrderEvent {
  final String orderId;
  final String reason;
  RejectOrderRequested(this.orderId, this.reason);
}

class BulkAssignAgentRequested extends OrderEvent {
  final List<String> orderIds;
  final String agentId;
  BulkAssignAgentRequested(this.orderIds, this.agentId);
}

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final RestaurantService service;

  OrderBloc(this.service) : super(OrdersLoading()) {
    
    // 1. SILENT LOAD EVENT
    on<LoadActiveOrders>((event, emit) async {
      // NEW: Only show the loading spinner if the screen is currently completely empty.
      // If we already have OrdersLoaded, skip this so the screen doesn't jump!
      if (state is! OrdersLoaded) {
        emit(OrdersLoading());
      }
      
      try {
        final activeOrders = await service.getRestaurantOrders(status: 'active');
        final historyOrders = await service.getRestaurantOrders(status: 'history');
        
        // WORKAROUND: Backend doesn't include 'at_gate' in 'active' status.
        // Try to fetch them explicitly and merge. If it fails, just use empty list for it.
        List<Order> atGateOrders = [];
        try {
          atGateOrders = await service.getRestaurantOrders(status: 'at_gate');
        } catch (_) {
          // Ignore if backend doesn't support filtering by 'at_gate'
        }

        final pending = activeOrders.where((o) => o.status == 'pending').toList();
        final preparing = activeOrders.where((o) => o.status == 'preparing').toList();
        
        final outForDelivery = activeOrders
            .where((o) => o.status == 'out_for_delivery' || o.status == 'at_gate')
            .toList();
            
        // Merge the explicitly fetched at_gate orders, ensuring no duplicates and strict status check
        for (var order in atGateOrders) {
          if ((order.status == 'at_gate' || order.status == 'out_for_delivery') && 
              !outForDelivery.any((o) => o.id == order.id)) {
            outForDelivery.add(order);
          }
        }
        
        // WORKAROUND 2: If the backend considers 'at_gate' as a history state, they might be in historyOrders.
        // Move them from historyOrders to outForDelivery.
        final atGateInHistory = historyOrders.where((o) => o.status == 'at_gate').toList();
        for (var order in atGateInHistory) {
          if (!outForDelivery.any((o) => o.id == order.id)) {
            outForDelivery.add(order);
          }
        }
        historyOrders.removeWhere((o) => o.status == 'at_gate');

        emit(OrdersLoaded(pending, preparing, outForDelivery, historyOrders)); 
      } catch (e) {
        // If it fails silently in the background, we don't want to destroy the currently viewed list
        if (state is! OrdersLoaded) {
          emit(OrdersError(e.toString()));
        }
      }
    }, transformer: droppable());

    // 2. ACCEPT ORDER
    on<AcceptOrderRequested>((event, emit) async {
      if (state is OrdersLoaded) {
        final currentState = state as OrdersLoaded;

        try {
          final List<Map<String, dynamic>> decisions = event.order.items.map((item) {
            return {
              "order_item_id": item.id,
              "accepted_qty": item.quantity,
            };
          }).toList();

          await service.prepareOrder(event.order.id, decisions);

          // HIDING FOR NOW
          // OrderAlarmService.instance.stopAlarm();
          // OrderAlarmService.stopNativeAlarm();
          
          add(LoadActiveOrders());
        } catch (e) {
          emit(OrdersError('Failed to accept order. Please try again.'));
          emit(currentState);
        }
      }
    }, transformer: droppable());

    // 3. REJECT ORDER 
    on<RejectOrderRequested>((event, emit) async {
      if (state is OrdersLoaded) {
        final currentState = state as OrdersLoaded;
        try {
          await service.rejectOrder(event.orderId, event.reason);

          // HIDING FOR NOW
          // OrderAlarmService.instance.stopAlarm();
          // OrderAlarmService.stopNativeAlarm();

          add(LoadActiveOrders());
        } catch (e) {
          emit(OrdersError(e.toString()));
          emit(currentState); 
        }
      }
    }, transformer: droppable());

    // 4. ASSIGN AGENT
    on<BulkAssignAgentRequested>((event, emit) async {
      if (state is OrdersLoaded) {
        final currentState = state as OrdersLoaded;
        try {
          await service.assignDeliveryAgent(event.agentId, event.orderIds);
          add(LoadActiveOrders()); 
        } catch (e) {
          emit(OrdersError(e.toString()));
          emit(currentState); 
        }
      }
    }, transformer: droppable());
  }
}