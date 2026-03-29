import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

class SimpleAssignmentSheet extends StatefulWidget {
  final List<dynamic> participants;
  final List<String> currentSelection;
  final Function(List<String>) onConfirm;

  const SimpleAssignmentSheet({
    super.key,
    required this.participants,
    required this.currentSelection,
    required this.onConfirm,
  });

  @override
  State<SimpleAssignmentSheet> createState() => _SimpleAssignmentSheetState();
}

class _SimpleAssignmentSheetState extends State<SimpleAssignmentSheet> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.currentSelection);
  }

  ImageProvider? _getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('who_split_this_item',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ).tr(),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.participants.length,
              itemBuilder: (context, index) {
                final p = widget.participants[index];
                final isSelected = _selectedIds.contains(p['id']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(p['id']);
                        } else {
                          _selectedIds.add(p['id']);
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
                            backgroundColor: p['color'],
                            child: _getAvatarImage(p['photoUrl']) == null
                                ? Text(
                                    p['name'][0],
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p['name'],
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (p['isPro'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.orange,
                                          Colors.deepOrange,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('pro',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 8,
                                      ),
                                    ).tr(),
                                  ),
                              ],
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
            onPressed: () => widget.onConfirm(_selectedIds),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text('done',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ).tr(),
          ),
        ],
      ),
    );
  }
}

class ComplexAssignmentSheet extends StatefulWidget {
  final List<dynamic> participants;
  final Map<String, int> initialMap;
  final int maxQty;
  final Function(Map<String, int>) onConfirm;

  const ComplexAssignmentSheet({
    super.key,
    required this.participants,
    required this.initialMap,
    required this.maxQty,
    required this.onConfirm,
  });

  @override
  State<ComplexAssignmentSheet> createState() => _ComplexAssignmentSheetState();
}

class _ComplexAssignmentSheetState extends State<ComplexAssignmentSheet> {
  late Map<String, int> _currentMap;

  @override
  void initState() {
    super.initState();
    _currentMap = Map.from(widget.initialMap);
  }

  ImageProvider? _getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    int currentAssignedTotal = _currentMap.values.fold(0, (sum, v) => sum + v);
    int remaining = widget.maxQty - currentAssignedTotal;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('assign_quantities',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ).tr(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: remaining < 0 ? Colors.red[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Left: $remaining",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: remaining < 0 ? Colors.red : Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.participants.length,
              itemBuilder: (context, index) {
                final p = widget.participants[index];
                final qty = _currentMap[p['id']] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: qty > 0 ? Colors.blue : Colors.grey[200]!,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: _getAvatarImage(p['photoUrl']),
                          backgroundColor: p['color'],
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (qty > 0) {
                                  setState(() {
                                    _currentMap[p['id']] = qty - 1;
                                    if (_currentMap[p['id']] == 0) {
                                      _currentMap.remove(p['id']);
                                    }
                                  });
                                  HapticFeedback.selectionClick();
                                }
                              },
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: qty > 0 ? Colors.red : Colors.grey,
                              ),
                            ),
                            Text(
                              "$qty",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (remaining > 0) {
                                  setState(() {
                                    _currentMap[p['id']] = qty + 1;
                                  });
                                  HapticFeedback.selectionClick();
                                }
                              },
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: remaining > 0
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: remaining >= 0
                ? () => widget.onConfirm(_currentMap)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text('confirm_quantities',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ).tr(),
          ),
        ],
      ),
    );
  }
}
