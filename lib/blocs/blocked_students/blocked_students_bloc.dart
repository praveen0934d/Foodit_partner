import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/blocked_student_model.dart';
import '../../services/restaurant_service.dart';

// ─── Events ──────────────────────────────────────────────────
abstract class BlockedStudentsEvent {}

class LoadBlockedStudents extends BlockedStudentsEvent {
  final String restaurantId;
  LoadBlockedStudents(this.restaurantId);
}

class ToggleBlockStudent extends BlockedStudentsEvent {
  final String restaurantId;
  final String studentId;
  final String? reason;
  ToggleBlockStudent(this.restaurantId, this.studentId, {this.reason});
}

// ─── States ──────────────────────────────────────────────────
abstract class BlockedStudentsState {}

class BlockedStudentsInitial extends BlockedStudentsState {}

class BlockedStudentsLoading extends BlockedStudentsState {}

class BlockedStudentsLoaded extends BlockedStudentsState {
  final List<BlockedStudent> students;
  BlockedStudentsLoaded(this.students);
}

class BlockedStudentsError extends BlockedStudentsState {
  final String message;
  BlockedStudentsError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────
class BlockedStudentsBloc extends Bloc<BlockedStudentsEvent, BlockedStudentsState> {
  final RestaurantService service;

  BlockedStudentsBloc(this.service) : super(BlockedStudentsInitial()) {

    on<LoadBlockedStudents>((event, emit) async {
      emit(BlockedStudentsLoading());
      try {
        final students = await service.getBlockedStudents(event.restaurantId);
        emit(BlockedStudentsLoaded(students));
      } catch (e) {
        emit(BlockedStudentsError(e.toString()));
      }
    });

    on<ToggleBlockStudent>((event, emit) async {
      final currentStudents = state is BlockedStudentsLoaded
          ? (state as BlockedStudentsLoaded).students
          : <BlockedStudent>[];

      try {
        final result = await service.toggleBlockStudent(
          event.restaurantId,
          event.studentId,
          reason: event.reason,
        );

        final isNowBlocked = result['blocked'] == true;

        if (!isNowBlocked) {
          // Student was unblocked — remove from list
          final updated = currentStudents
              .where((s) => s.studentId != event.studentId)
              .toList();
          emit(BlockedStudentsLoaded(updated));
        } else {
          // Student was blocked — reload to get fresh data
          add(LoadBlockedStudents(event.restaurantId));
        }
      } catch (e) {
        emit(BlockedStudentsError(e.toString()));
        // Restore the list so the UI doesn't break
        if (currentStudents.isNotEmpty) {
          emit(BlockedStudentsLoaded(currentStudents));
        }
      }
    });
  }
}
