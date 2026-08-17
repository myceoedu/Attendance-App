import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_theme.dart';
import '../../utils/app_route.dart';
import '../../models/app_user.dart';
import '../../services/supabase_service.dart';
import '../../widgets/empty_state.dart';
import '../../utils/debouncer.dart';
import 'admin_add_employee_screen.dart';
import 'admin_employee_edit_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<AppUser> _employees = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebounce = Debouncer();

  static const Color _navy = Color(0xFF14213D);
  static const Color _pageBg = Color(0xFFF5F6F8);
  static const Color _rowBorder = Color(0xFFE4E6EB);
  static const Color _inputBorder = Color(0xFFD8DBE2);
  static const Color _muted = Color(0xFF9AA1AD);
  static const Color _mutedLight = Color(0xFFB4B9C2);
  static const Color _avatarBg = Color(0xFFE9EBF2);

  TextStyle get _ui => GoogleFonts.inter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    try {
      final data = await SupabaseService.getAllEmployees(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _employees = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  List<AppUser> get _filteredEmployees {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _employees;
    return _employees.where((employee) {
      return employee.name.toLowerCase().contains(query) ||
          employee.username.toLowerCase().contains(query) ||
          employee.email.toLowerCase().contains(query);
    }).toList();
  }

  bool _openingAdd = false;

  Future<void> _openEditor(AppUser e) async {
    final ok = await pushAppPage<bool>(
      context,
      AdminEmployeeEditScreen(employee: e),
    );
    if (ok == true && mounted) {
      await _load(forceRefresh: true);
    }
  }

  Future<void> _openAdd() async {
    if (_openingAdd || _loading) return;
    _openingAdd = true;
    try {
      final created = await pushAppPage<bool>(
        context,
        const AdminAddEmployeeScreen(),
      );
      if (created == true && mounted) {
        await _load(forceRefresh: true);
      }
    } finally {
      _openingAdd = false;
    }
  }

  Widget _header() {
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Employees',
                      style: _ui.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: _navy,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _avatarBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_employees.length}',
                      style: _ui.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Add employee',
                    child: Material(
                      color: _navy,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: _loading ? null : _openAdd,
                        borderRadius: BorderRadius.circular(8),
                        child: const SizedBox(
                          width: 30,
                          height: 30,
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ColoredBox(
            color: _rowBorder,
            child: SizedBox(height: 1, width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _searchBlock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FILTER AND SEARCH',
            style: _ui.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.06 * 11,
              color: _muted,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _searchDebounce(() {
                if (mounted) setState(() {});
              }),
              textInputAction: TextInputAction.search,
              style: _ui.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _navy,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name, username, or email',
                hintStyle: _ui.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _mutedLight,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                prefixIconColor: _muted,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _navy, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _employeeRow(AppUser e) {
    final name = e.name.isNotEmpty
        ? e.name
        : (e.username.isNotEmpty ? e.username : 'Unnamed');
    final initial = name[0].toUpperCase();

    return KeyedSubtree(
      key: ValueKey<String>(e.id),
      child: RepaintBoundary(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _openEditor(e),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _rowBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: _avatarBg,
                    child: Text(
                      initial,
                      style: _ui.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _navy,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ui.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 13.5,
                            color: _navy,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ui.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _muted,
                          ),
                        ),
                        if (e.username.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            e.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ui.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: _mutedLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: _mutedLight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _filteredEmployees;

    // No nested [Scaffold] — [AdminShell] already owns the scaffold.
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: SizedBox.expand(
        child: ColoredBox(
          color: _pageBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _navy,
                          strokeWidth: 2.4,
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: _ui.copyWith(color: AppColors.danger),
                        ),
                      )
                    : _employees.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: 'No employees yet',
                        subtitle:
                            'Tap + to create a login with email, username, and password.',
                        action: FilledButton.icon(
                          onPressed: _openAdd,
                          style: FilledButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(
                            'Add employee',
                            style: _ui.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          _searchBlock(),
                          Expanded(
                            child: filteredEmployees.isEmpty
                                ? const EmptyState(
                                    icon: Icons.search_off,
                                    title: 'No employees match your search',
                                    subtitle:
                                        'Try another name, username, or email',
                                  )
                                : RefreshIndicator(
                                    color: _navy,
                                    onRefresh: () async {
                                      setState(() => _loading = true);
                                      await _load(forceRefresh: true);
                                    },
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        4,
                                        16,
                                        16,
                                      ),
                                      addAutomaticKeepAlives: false,
                                      cacheExtent: 400,
                                      itemCount: filteredEmployees.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (_, i) =>
                                          _employeeRow(filteredEmployees[i]),
                                    ),
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
