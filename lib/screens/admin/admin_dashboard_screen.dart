import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_menu_widgets.dart';
import 'user_admin_detail_screen.dart';

enum _AdminUserStatusFilter { all, admins, premium, free }

enum _AdminUserContactFilter { all, withContact, missingContact }

enum _AdminUserSort { newest, oldest, nameAZ, nameZA, pointsHigh, premiumFirst }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _searchQuery = '';
  _AdminUserStatusFilter _statusFilter = _AdminUserStatusFilter.all;
  _AdminUserContactFilter _contactFilter = _AdminUserContactFilter.all;
  _AdminUserSort _sort = _AdminUserSort.newest;
  final TextEditingController _searchController = TextEditingController();

  Stream<QuerySnapshot> _getUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'admin_dashboard'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getUsersStream(),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final allUsers = snapshot.data?.docs ?? [];
          final filteredUsers = _filterAndSortUsers(allUsers);

          return Column(
            children: [
              _buildSearchHeader(
                context,
                totalCount: allUsers.length,
                shownCount: filteredUsers.length,
              ),
              Expanded(
                child: _buildUsersBody(
                  context,
                  isLoading: isLoading,
                  allUsers: allUsers,
                  filteredUsers: filteredUsers,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchHeader(
    BuildContext context, {
    required int totalCount,
    required int shownCount,
  }) {
    final activeFilters = _activeFilterCount;
    final isFiltered =
        activeFilters > 0 ||
        _searchQuery.trim().isNotEmpty ||
        _sort != _AdminUserSort.newest;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'search_by_name_email_phone_or_uid'.tr(),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              _buildFilterButton(context, activeFilters),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.group_rounded, size: 18, color: Colors.blueGrey[500]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  shownCount == totalCount
                      ? 'admin_users_count'.tr(
                          namedArgs: {'count': totalCount.toString()},
                        )
                      : 'admin_users_filtered_count'.tr(
                          namedArgs: {
                            'shown': shownCount.toString(),
                            'total': totalCount.toString(),
                          },
                        ),
                  style: TextStyle(
                    color: Colors.blueGrey[600],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isFiltered)
                TextButton(
                  onPressed: _resetFiltersAndSearch,
                  child: Text('admin_reset_filters'.tr()),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, int activeFilters) {
    final hasActiveFilters =
        activeFilters > 0 || _sort != _AdminUserSort.newest;

    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Tooltip(
              message: 'admin_user_filters'.tr(),
              child: OutlinedButton(
                onPressed: _openUserFiltersSheet,
                style: OutlinedButton.styleFrom(
                  backgroundColor: hasActiveFilters
                      ? Colors.blue.withValues(alpha: 0.08)
                      : Colors.grey[100],
                  foregroundColor: hasActiveFilters
                      ? Colors.blue[700]
                      : Colors.blueGrey,
                  side: BorderSide(
                    color: hasActiveFilters
                        ? Colors.blue.withValues(alpha: 0.35)
                        : Colors.transparent,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
          if (activeFilters > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  activeFilters.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersBody(
    BuildContext context, {
    required bool isLoading,
    required List<QueryDocumentSnapshot<Object?>> allUsers,
    required List<QueryDocumentSnapshot<Object?>> filteredUsers,
  }) {
    if (isLoading && allUsers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (allUsers.isEmpty) {
      return Center(child: Text('no_users_found'.tr()));
    }

    if (filteredUsers.isEmpty) {
      return _buildEmptyFilteredState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final userDoc = filteredUsers[index];
        final userData = userDoc.data() as Map<String, dynamic>;
        final uid = userDoc.id;
        final name = _displayName(userData);
        final email =
            userData['email'] ??
            userData['phoneNumber'] ??
            'no_contact_info'.tr();
        final subtitle = '$email\nUID: $uid';
        final isPremium = userData['isPremium'] ?? false;
        final isAdmin = userData['isAdmin'] ?? false;

        return ProfileCoolTile(
          icon: isAdmin
              ? Icons.admin_panel_settings_rounded
              : Icons.person_rounded,
          title: name,
          subtitle: subtitle,
          color: isAdmin
              ? Colors.blueGrey
              : (isPremium ? Colors.amber : Colors.blue),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  UserAdminDetailScreen(uid: uid, userData: userData),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 48,
              color: Colors.blueGrey[300],
            ),
            const SizedBox(height: 12),
            Text(
              'admin_no_matching_users'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueGrey[700],
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _resetFiltersAndSearch,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('admin_clear_filters'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _openUserFiltersSheet() {
    var selectedStatus = _statusFilter;
    var selectedContact = _contactFilter;
    var selectedSort = _sort;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.86,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'admin_user_filters'.tr(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildSheetSectionTitle('admin_status_filter'.tr()),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _AdminUserStatusFilter.values.map((filter) {
                          return ChoiceChip(
                            label: Text(_statusFilterLabel(filter)),
                            avatar: Icon(_statusFilterIcon(filter), size: 18),
                            selected: selectedStatus == filter,
                            onSelected: (_) {
                              setModalState(() => selectedStatus = filter);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      _buildSheetSectionTitle('admin_contact_filter'.tr()),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _AdminUserContactFilter.values.map((filter) {
                          return ChoiceChip(
                            label: Text(_contactFilterLabel(filter)),
                            avatar: Icon(_contactFilterIcon(filter), size: 18),
                            selected: selectedContact == filter,
                            onSelected: (_) {
                              setModalState(() => selectedContact = filter);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      _buildSheetSectionTitle('admin_sort'.tr()),
                      const SizedBox(height: 6),
                      ..._AdminUserSort.values.map((sort) {
                        final selected = selectedSort == sort;
                        return ListTile(
                          onTap: () {
                            setModalState(() => selectedSort = sort);
                          },
                          leading: Icon(_sortIcon(sort)),
                          title: Text(
                            _sortLabel(sort),
                            style: TextStyle(
                              color: selected ? Colors.blue[700] : null,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: selected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.blue[700],
                                )
                              : const Icon(Icons.circle_outlined),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      }),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  selectedStatus = _AdminUserStatusFilter.all;
                                  selectedContact = _AdminUserContactFilter.all;
                                  selectedSort = _AdminUserSort.newest;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text('admin_reset_filters'.tr()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                setState(() {
                                  _statusFilter = selectedStatus;
                                  _contactFilter = selectedContact;
                                  _sort = selectedSort;
                                });
                                Navigator.pop(sheetContext);
                              },
                              icon: const Icon(Icons.check_rounded),
                              label: Text('admin_apply_filters'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.blueGrey[700],
        fontWeight: FontWeight.w900,
      ),
    );
  }

  List<QueryDocumentSnapshot<Object?>> _filterAndSortUsers(
    List<QueryDocumentSnapshot<Object?>> users,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = users.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (!_matchesSearch(doc.id, data, query)) return false;
      if (!_matchesStatus(data)) return false;
      if (!_matchesContact(data)) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      switch (_sort) {
        case _AdminUserSort.oldest:
          return _timestampMillis(
            aData,
            'createdAt',
          ).compareTo(_timestampMillis(bData, 'createdAt'));
        case _AdminUserSort.nameAZ:
          return _displayName(
            aData,
          ).toLowerCase().compareTo(_displayName(bData).toLowerCase());
        case _AdminUserSort.nameZA:
          return _displayName(
            bData,
          ).toLowerCase().compareTo(_displayName(aData).toLowerCase());
        case _AdminUserSort.pointsHigh:
          return _intValue(
            bData['points'],
          ).compareTo(_intValue(aData['points']));
        case _AdminUserSort.premiumFirst:
          final premiumCompare = _boolInt(
            bData['isPremium'],
          ).compareTo(_boolInt(aData['isPremium']));
          if (premiumCompare != 0) return premiumCompare;
          return _displayName(
            aData,
          ).toLowerCase().compareTo(_displayName(bData).toLowerCase());
        case _AdminUserSort.newest:
          return _timestampMillis(
            bData,
            'createdAt',
          ).compareTo(_timestampMillis(aData, 'createdAt'));
      }
    });

    return filtered;
  }

  bool _matchesSearch(String uid, Map<String, dynamic> data, String query) {
    if (query.isEmpty) return true;

    final haystack = [
      data['displayName'],
      data['email'],
      data['phoneNumber'],
      data['loginPlatform'],
      data['isoCode'],
      uid,
    ].whereType<Object>().join(' ').toLowerCase();

    return haystack.contains(query);
  }

  bool _matchesStatus(Map<String, dynamic> data) {
    switch (_statusFilter) {
      case _AdminUserStatusFilter.admins:
        return _boolValue(data['isAdmin']);
      case _AdminUserStatusFilter.premium:
        return _boolValue(data['isPremium']);
      case _AdminUserStatusFilter.free:
        return !_boolValue(data['isPremium']);
      case _AdminUserStatusFilter.all:
        return true;
    }
  }

  bool _matchesContact(Map<String, dynamic> data) {
    final hasContact = _hasContact(data);
    switch (_contactFilter) {
      case _AdminUserContactFilter.withContact:
        return hasContact;
      case _AdminUserContactFilter.missingContact:
        return !hasContact;
      case _AdminUserContactFilter.all:
        return true;
    }
  }

  bool _hasContact(Map<String, dynamic> data) {
    final email = (data['email'] ?? '').toString().trim();
    final phone = (data['phoneNumber'] ?? '').toString().trim();
    return email.isNotEmpty || phone.isNotEmpty;
  }

  String _displayName(Map<String, dynamic> data) {
    final name = (data['displayName'] ?? '').toString().trim();
    return name.isEmpty ? 'unknown_user'.tr() : name;
  }

  int _timestampMillis(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _boolValue(Object? value) => value == true;

  int _boolInt(Object? value) => _boolValue(value) ? 1 : 0;

  int get _activeFilterCount {
    var count = 0;
    if (_statusFilter != _AdminUserStatusFilter.all) count++;
    if (_contactFilter != _AdminUserContactFilter.all) count++;
    return count;
  }

  void _resetFiltersAndSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = _AdminUserStatusFilter.all;
      _contactFilter = _AdminUserContactFilter.all;
      _sort = _AdminUserSort.newest;
    });
  }

  String _statusFilterLabel(_AdminUserStatusFilter filter) {
    switch (filter) {
      case _AdminUserStatusFilter.admins:
        return 'admin_filter_admins'.tr();
      case _AdminUserStatusFilter.premium:
        return 'admin_filter_premium'.tr();
      case _AdminUserStatusFilter.free:
        return 'admin_filter_free'.tr();
      case _AdminUserStatusFilter.all:
        return 'admin_filter_all_users'.tr();
    }
  }

  IconData _statusFilterIcon(_AdminUserStatusFilter filter) {
    switch (filter) {
      case _AdminUserStatusFilter.admins:
        return Icons.admin_panel_settings_rounded;
      case _AdminUserStatusFilter.premium:
        return Icons.workspace_premium_rounded;
      case _AdminUserStatusFilter.free:
        return Icons.person_outline_rounded;
      case _AdminUserStatusFilter.all:
        return Icons.group_rounded;
    }
  }

  String _contactFilterLabel(_AdminUserContactFilter filter) {
    switch (filter) {
      case _AdminUserContactFilter.withContact:
        return 'admin_contact_with_contact'.tr();
      case _AdminUserContactFilter.missingContact:
        return 'admin_contact_missing_contact'.tr();
      case _AdminUserContactFilter.all:
        return 'admin_contact_all'.tr();
    }
  }

  IconData _contactFilterIcon(_AdminUserContactFilter filter) {
    switch (filter) {
      case _AdminUserContactFilter.withContact:
        return Icons.contact_mail_rounded;
      case _AdminUserContactFilter.missingContact:
        return Icons.contact_mail_outlined;
      case _AdminUserContactFilter.all:
        return Icons.contacts_rounded;
    }
  }

  String _sortLabel(_AdminUserSort sort) {
    switch (sort) {
      case _AdminUserSort.oldest:
        return 'admin_sort_oldest'.tr();
      case _AdminUserSort.nameAZ:
        return 'admin_sort_name_az'.tr();
      case _AdminUserSort.nameZA:
        return 'admin_sort_name_za'.tr();
      case _AdminUserSort.pointsHigh:
        return 'admin_sort_points_high'.tr();
      case _AdminUserSort.premiumFirst:
        return 'admin_sort_premium_first'.tr();
      case _AdminUserSort.newest:
        return 'admin_sort_newest'.tr();
    }
  }

  IconData _sortIcon(_AdminUserSort sort) {
    switch (sort) {
      case _AdminUserSort.oldest:
        return Icons.history_rounded;
      case _AdminUserSort.nameAZ:
        return Icons.sort_by_alpha_rounded;
      case _AdminUserSort.nameZA:
        return Icons.sort_by_alpha_rounded;
      case _AdminUserSort.pointsHigh:
        return Icons.stars_rounded;
      case _AdminUserSort.premiumFirst:
        return Icons.workspace_premium_rounded;
      case _AdminUserSort.newest:
        return Icons.schedule_rounded;
    }
  }
}
