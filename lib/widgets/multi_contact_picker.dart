import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:split_bill_app/services/contact_service.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';

class MultiContactPicker extends StatefulWidget {
  final List<String> alreadySelectedIds;
  const MultiContactPicker({super.key, this.alreadySelectedIds = const []});

  @override
  State<MultiContactPicker> createState() => _MultiContactPickerState();
}

class _MultiContactPickerState extends State<MultiContactPicker> {
  final ContactService _contactService = ContactService();

  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _selectedIds = {}; // Using contact.id for selection

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.alreadySelectedIds.toSet();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _contactService.getAllContacts();
    if (mounted) {
      if (contacts == null) {
        // Permission denied
        Navigator.pop(context, null);
        return;
      }

      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts.where((c) {
          final nameMatches = c.displayName.toLowerCase().contains(
            query.toLowerCase(),
          );
          final phoneMatches = c.phones.any((p) => p.number.contains(query));
          return nameMatches || phoneMatches;
        }).toList();
      }
    });
  }

  void _toggleSelection(Contact contact) {
    setState(() {
      if (_selectedIds.contains(contact.id)) {
        _selectedIds.remove(contact.id);
      } else {
        _selectedIds.add(contact.id);
      }
    });
  }

  void _returnSelection() {
    final selectedContacts = _allContacts
        .where((c) => _selectedIds.contains(c.id))
        .toList();
    Navigator.pop(context, selectedContacts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Contacts",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_selectedIds.isNotEmpty)
              Text(
                "${_selectedIds.length} selected",
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _returnSelection,
              child: const Text(
                "Add",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: "Search name or phone...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // Contact List
          Expanded(
            child: _isLoading
                ? const LoadingStateWidget(message: "Loading contacts...")
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final isSelected = _selectedIds.contains(contact.id);
                      final hasPhone = contact.phones.isNotEmpty;

                      if (!hasPhone) return const SizedBox.shrink();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[200],
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : Text(
                                  contact.displayName.isNotEmpty
                                      ? contact.displayName[0]
                                      : "?",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                        ),
                        title: Text(
                          contact.displayName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          contact.phones.isNotEmpty
                              ? contact.phones.first.number
                              : "No number",
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (val) => _toggleSelection(contact),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onTap: () => _toggleSelection(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton(
              onPressed: _returnSelection,
              child: const Icon(Icons.check),
            )
          : null,
    );
  }
}
