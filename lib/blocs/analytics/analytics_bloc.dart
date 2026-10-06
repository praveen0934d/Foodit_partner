import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/order_model.dart';
import '../../services/restaurant_service.dart';

abstract class AnalyticsState {}
class AnalyticsLoading extends AnalyticsState {}
class AnalyticsLoaded extends AnalyticsState {
  final List<Order> deliveredOrders;
  final double totalRevenue;
  final int totalOrders;
  final String currentFilter;

  AnalyticsLoaded({
    required this.deliveredOrders,
    required this.totalRevenue,
    required this.totalOrders,
    required this.currentFilter,
  });
}
class AnalyticsError extends AnalyticsState {
  final String message;
  AnalyticsError(this.message);
}

abstract class AnalyticsEvent {}
class LoadAnalytics extends AnalyticsEvent {
  final String dateFilter; // 'today', 'this_week', 'this_month'
  LoadAnalytics({this.dateFilter = 'today'});
}

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final RestaurantService service;

  AnalyticsBloc(this.service) : super(AnalyticsLoading()) {
    on<LoadAnalytics>((event, emit) async {
      emit(AnalyticsLoading());
      try {
        // Fetch only successfully delivered orders for accurate revenue
        final orders = await service.getRestaurantOrders(
          status: 'delivered', 
          date: event.dateFilter
        );
        
        // Calculate totals
        double revenue = 0;
        for (var order in orders) {
          revenue += order.totalAmount;
        }

        emit(AnalyticsLoaded(
          deliveredOrders: orders,
          totalRevenue: revenue,
          totalOrders: orders.length,
          currentFilter: event.dateFilter,
        ));
      } catch (e) {
        emit(AnalyticsError(e.toString()));
      }
    });
  }
}