import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocked_students/blocked_students_bloc.dart';
import '../blocs/restaurant/restaurant_bloc.dart';
import '../models/blocked_student_model.dart';

// ─── Design tokens (matching app-wide palette) ────────────────
const _kBrand     = Color(0xFFFF5722);
const _kBrandDeep = Color(0xFFBF360C);
const _kSurface   = Color(0xFFF7F8FA);
const _kTextDark  = Color(0xFF1A1A2E);
const _kTextMid   = Color(0xFF6B7280);
const _kTextLight = Color(0xFF9CA3AF);
const _kGreen     = Color(0xFF22C55E);
const _kRed       = Color(0xFFEF4444);

class BlockedStudentsTab extends StatefulWidget {
  const BlockedStudentsTab({super.key});

  @override
  State<BlockedStudentsTab> createState() => _BlockedStudentsTabState();
}

class _BlockedStudentsTabState extends State<BlockedStudentsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _kBrand.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.construction_rounded,
                        size: 48,
                        color: _kBrand,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This feature will be updated soon\nonce the backend is ready.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _kTextMid,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Gradient Header ─────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBrandDeep, _kBrand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'MANAGE',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Blocked Students',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              BlocBuilder<BlockedStudentsBloc, BlockedStudentsState>(
                builder: (context, state) {
                  final count = state is BlockedStudentsLoaded ? state.students.length : 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '$count blocked',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Search Bar ──────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kTextDark,
          ),
          decoration: InputDecoration(
            hintText: 'Search by name or phone...',
            hintStyle: const TextStyle(
              color: _kTextLight,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            prefixIcon: const Icon(Icons.search_rounded, color: _kTextLight, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.close_rounded, color: _kTextLight, size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ─── Body ────────────────────────────────────────────────────
  Widget _buildBody() {
    return BlocBuilder<BlockedStudentsBloc, BlockedStudentsState>(
      builder: (context, state) {
        if (state is BlockedStudentsLoading) {
          return const Center(
            child: CircularProgressIndicator(color: _kBrand, strokeWidth: 2.5),
          );
        }

        if (state is BlockedStudentsError) {
          return _buildErrorState(context, state.message);
        }

        if (state is BlockedStudentsLoaded) {
          final filtered = _filterStudents(state.students);

          if (state.students.isEmpty) {
            return _buildEmptyState();
          }

          if (filtered.isEmpty) {
            return _buildNoSearchResults();
          }

          return RefreshIndicator(
            color: _kBrand,
            onRefresh: () async => _refreshList(context),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _BlockedStudentCard(
                student: filtered[index],
                onUnblock: () => _confirmUnblock(context, filtered[index]),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  List<BlockedStudent> _filterStudents(List<BlockedStudent> students) {
    if (_searchQuery.isEmpty) return students;
    return students.where((s) {
      return s.studentName.toLowerCase().contains(_searchQuery) ||
          (s.studentPhone?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  void _refreshList(BuildContext context) {
    final restaurantState = context.read<RestaurantBloc>().state;
    if (restaurantState is RestaurantLoaded) {
      context.read<BlockedStudentsBloc>().add(
        LoadBlockedStudents(restaurantState.restaurant.id),
      );
    }
  }

  // ─── Unblock Confirmation Dialog ─────────────────────────────
  void _confirmUnblock(BuildContext context, BlockedStudent student) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: _kGreen, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unblock Student?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kTextDark),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to unblock ${student.studentName}? They will be able to place orders again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kTextMid, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _doUnblock(context, student);
                      },
                      child: const Text(
                        'Unblock',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _doUnblock(BuildContext context, BlockedStudent student) {
    final restaurantState = context.read<RestaurantBloc>().state;
    if (restaurantState is RestaurantLoaded) {
      context.read<BlockedStudentsBloc>().add(
        ToggleBlockStudent(restaurantState.restaurant.id, student.studentId),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kGreen.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kGreen, Color(0xFF16A34A)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${student.studentName} Unblocked',
                        style: const TextStyle(
                          color: _kTextDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Student can now place orders',
                        style: TextStyle(
                          color: _kTextMid,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // ─── Empty State ─────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sentiment_satisfied_alt_rounded,
                size: 64,
                color: _kGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Blocked Students',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _kTextDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All students can currently order from\nyour restaurant. Great going! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kTextMid,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── No Search Results ───────────────────────────────────────
  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: _kTextLight.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No Results Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kTextDark),
            ),
            const SizedBox(height: 6),
            Text(
              'No blocked students match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextMid, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error State ─────────────────────────────────────────────
  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kTextDark),
            ),
            const SizedBox(height: 8),
            Text(
              message.replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextMid, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _refreshList(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrand,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              label: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Blocked Student Card ─────────────────────────────────────
class _BlockedStudentCard extends StatelessWidget {
  final BlockedStudent student;
  final VoidCallback onUnblock;
  const _BlockedStudentCard({required this.student, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final initials = student.studentName.isNotEmpty
        ? student.studentName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '??';

    final timeAgo = _formatTimeAgo(student.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: student.profilePhoto != null
                    ? null
                    : LinearGradient(
                        colors: [_kRed.withValues(alpha: 0.8), _kBrand],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                shape: BoxShape.circle,
                image: student.profilePhoto != null
                    ? DecorationImage(
                        image: NetworkImage(student.profilePhoto!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: student.profilePhoto == null
                  ? Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.studentName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kTextDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (student.studentPhone != null)
                    Text(
                      student.studentPhone!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextMid,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          student.reason != null && student.reason!.isNotEmpty
                              ? student.reason!
                              : 'No reason specified',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: student.reason != null && student.reason!.isNotEmpty
                                ? _kRed
                                : _kTextLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded, size: 12, color: _kTextLight.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kTextLight.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Unblock Button
            GestureDetector(
              onTap: onUnblock,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.3), width: 1.2),
                ),
                child: const Text(
                  'Unblock',
                  style: TextStyle(
                    color: _kGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
