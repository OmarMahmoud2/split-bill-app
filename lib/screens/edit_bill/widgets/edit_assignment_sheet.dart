import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditAssignmentSheet extends StatefulWidget {
  final List<Map<String, dynamic>> participants;
  final List<String> currentSelection;
  final Function(List<String>) onConfirm;

  const EditAssignmentSheet({
    super.key,
    required this.participants,
    required this.currentSelection,
    required this.onConfirm,
  });

  @override
  State<EditAssignmentSheet> createState() => _EditAssignmentSheetState();

  static void show(
    BuildContext context, {
    required List<Map<String, dynamic>> participants,
    required List<String> currentSelection,
    required Function(List<String>) onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EditAssignmentSheet(
        participants: participants,
        currentSelection: currentSelection,
        onConfirm: onConfirm,
      ),
    );
  }
}

class _EditAssignmentSheetState extends State<EditAssignmentSheet> {
  late List<String> _tempSelection;

  @override
  void initState() {
    super.initState();
    _tempSelection = List.from(widget.currentSelection);
  }

  ImageProvider? _getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Who split this item?",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.participants.length,
              itemBuilder: (context, index) {
                final p = widget.participants[index];
                final isSelected = _tempSelection.contains(p['id']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _tempSelection.remove(p['id']);
                        } else {
                          _tempSelection.add(p['id']);
                        }
                      });
                      HapticFeedback.selectionClick();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: _getAvatarImage(p['photoUrl']),
                            backgroundColor: p['color'] ?? Colors.blue,
                            child: _getAvatarImage(p['photoUrl']) == null
                                ? Text(
                                    p['name'][0],
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.blue,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.onConfirm(_tempSelection);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "Confirm Selection",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
