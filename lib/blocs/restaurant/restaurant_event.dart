abstract class RestaurantEvent {}
class LoadRestaurant extends RestaurantEvent {}
class ToggleOpenStatus extends RestaurantEvent {}
class ToggleMenuItem extends RestaurantEvent {
  final String itemId;
  ToggleMenuItem(this.itemId);
}
class AddMenuItemRequested extends RestaurantEvent {
  final Map<String, dynamic> itemData;
  AddMenuItemRequested(this.itemData);
}

class EditMenuItemRequested extends RestaurantEvent {
  final String itemId;
  final Map<String, dynamic> itemData;
  EditMenuItemRequested(this.itemId, this.itemData);
}

// Add this new event class
class DeleteMenuItemRequested extends RestaurantEvent {
  final String itemId;
  DeleteMenuItemRequested(this.itemId);
}

class UpdateRestaurantRequested extends RestaurantEvent {
  final String id;
  final Map<String, dynamic> data;
  UpdateRestaurantRequested(this.id, this.data);
}