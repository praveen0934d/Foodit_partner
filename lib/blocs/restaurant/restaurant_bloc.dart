import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/restaurant_model.dart';
import '../../services/restaurant_service.dart';
import 'restaurant_event.dart'; 

abstract class RestaurantState {}

class RestaurantInitial extends RestaurantState {}
class RestaurantLoading extends RestaurantState {}
class RestaurantLoaded extends RestaurantState {
  final Restaurant restaurant;
  RestaurantLoaded(this.restaurant);
}
class RestaurantEmpty extends RestaurantState {}
class RestaurantError extends RestaurantState {
  final String message;
  RestaurantError(this.message);
}

class RestaurantBloc extends Bloc<RestaurantEvent, RestaurantState> {
  final RestaurantService service;

  RestaurantBloc(this.service) : super(RestaurantLoading()) {
    
    on<LoadRestaurant>((event, emit) async {
      emit(RestaurantLoading());
      try {
        final restaurant = await service.getMyRestaurant();
        if (restaurant != null) {
          emit(RestaurantLoaded(restaurant));
        } else {
          emit(RestaurantEmpty());
        }
      } catch (e) {
        emit(RestaurantError(e.toString()));
      }
    });

    on<ToggleOpenStatus>((event, emit) async {
      if (state is RestaurantLoaded) {
        final currentState = state as RestaurantLoaded;
        final oldRestaurant = currentState.restaurant;
        
        emit(RestaurantLoaded(oldRestaurant.copyWith(isOpen: !oldRestaurant.isOpen)));
        
        try {
          await service.toggleRestaurantStatus(oldRestaurant.id);
          final freshRest = await service.getMyRestaurant();
          emit(RestaurantLoaded(freshRest ?? oldRestaurant.copyWith(isOpen: !oldRestaurant.isOpen)));
        } catch (e) {
          // The backend threw an error. Let's check if it actually saved the change anyway.
          final freshRest = await service.getMyRestaurant();
          
          if (freshRest != null && freshRest.isOpen != oldRestaurant.isOpen) {
            // The DB was updated successfully, the backend just crashed afterwards!
            // Silently accept it without showing any error snackbar.
            emit(RestaurantLoaded(freshRest));
          } else {
            // It actually failed to update the DB. Now we show the error and revert the UI.
            emit(RestaurantError('Failed to update status on server'));
            emit(RestaurantLoaded(freshRest ?? oldRestaurant));
          }
        }
      }
    });

    on<ToggleMenuItem>((event, emit) async {
      if (state is RestaurantLoaded) {
        final currentState = state as RestaurantLoaded;
        final oldRestaurant = currentState.restaurant;

        final optimisticItems = oldRestaurant.menuItems.map((item) {
          return item.id == event.itemId ? item.copyWith(isAvailable: !item.isAvailable) : item;
        }).toList();
        
        emit(RestaurantLoaded(oldRestaurant.copyWith(menuItems: optimisticItems)));

        try {
          final isAvailable = await service.toggleMenuItemStatus(oldRestaurant.id, event.itemId);
          
          final serverItems = oldRestaurant.menuItems.map((item) {
            return item.id == event.itemId ? item.copyWith(isAvailable: isAvailable) : item;
          }).toList();
          emit(RestaurantLoaded(oldRestaurant.copyWith(menuItems: serverItems)));
        } catch (e) {
          emit(RestaurantError('Failed to update menu item on server'));
          emit(RestaurantLoaded(oldRestaurant));
        }
      }
    });

    on<AddMenuItemRequested>((event, emit) async {
      if (state is RestaurantLoaded) {
        final currentState = state as RestaurantLoaded;
        try {
          final newItem = await service.addMenuItem(currentState.restaurant.id, event.itemData);
          final updatedItems = List<MenuItem>.from(currentState.restaurant.menuItems)..insert(0, newItem);
          emit(RestaurantLoaded(currentState.restaurant.copyWith(menuItems: updatedItems)));
        } catch (e) {
          emit(RestaurantError(e.toString()));
          emit(RestaurantLoaded(currentState.restaurant)); 
        }
      }
    });

    on<EditMenuItemRequested>((event, emit) async {
      if (state is RestaurantLoaded) {
        final currentState = state as RestaurantLoaded;
        try {
          final updatedItem = await service.updateMenuItem(currentState.restaurant.id, event.itemId, event.itemData);
          final updatedItems = currentState.restaurant.menuItems.map((item) {
            return item.id == event.itemId ? updatedItem : item;
          }).toList();
          emit(RestaurantLoaded(currentState.restaurant.copyWith(menuItems: updatedItems)));
        } catch (e) {
          emit(RestaurantError(e.toString()));
          emit(RestaurantLoaded(currentState.restaurant));
        }
      }
    });

    on<DeleteMenuItemRequested>((event, emit) async {
      if (state is RestaurantLoaded) {
        final currentState = state as RestaurantLoaded;
        final restaurantId = currentState.restaurant.id;
        
        try {
          await service.deleteMenuItem(restaurantId, event.itemId);
          add(LoadRestaurant()); 
        } catch (e) {
          emit(RestaurantError(e.toString()));
          emit(currentState); 
        }
      }
    });

    on<UpdateRestaurantRequested>((event, emit) async {
      if (state is RestaurantLoaded) {
        final currentState = state as RestaurantLoaded;
        try {
          // 1. Wait for backend to confirm update
          await service.updateRestaurant(event.id, event.data);
          
          // 2. Instantly update the local UI data to feel snappy
          final updatedRest = currentState.restaurant.copyWith(
            name: event.data['name'],
            description: event.data['description'],
            phone: event.data['phone'],
            minOrderAmount: event.data['min_order_amount'],
            images: event.data['images'],
          );
          
          emit(RestaurantLoaded(updatedRest));
          
          // 3. Silently refetch from backend just to be safe
          add(LoadRestaurant()); 
        } catch (e) {
          // If it fails, emit the error so the UI can catch it and keep the screen open!
          emit(RestaurantError(e.toString()));
          emit(currentState); 
        }
      }
    });
  }  
}