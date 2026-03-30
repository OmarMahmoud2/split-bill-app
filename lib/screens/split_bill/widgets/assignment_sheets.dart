import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/utils/image_utils.dart';

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
    return ImageUtils.getAvatarImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final allParticipantIds = widget.participants
        .map<String>((participant) => participant['id'] as String)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'who_split_this_item',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ).tr(),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.participants.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final p = widget.participants[index];
              final isSelected = _selectedIds.contains(p['id']);
              return Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade100,
                    width: 1.5,
                  ),
                ),
                child: ListTile(
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
                  leading: CircleAvatar(
                    backgroundImage: _getAvatarImage(p['photoUrl']),
                    backgroundColor: p['color'],
                    child: _getAvatarImage(p['photoUrl']) == null
                        ? Text(
                            p['name'][0],
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          p['name'],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
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
                              colors: [Colors.orange, Colors.deepOrange],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'pro',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
                          ).tr(),
                        ),
                    ],
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => widget.onConfirm(allParticipantIds),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  minimumSize: const Size(double.infinity, 56),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'for_all',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ).tr(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => widget.onConfirm(_selectedIds),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'done',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ).tr(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
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
    return ImageUtils.getAvatarImage(url);
  }

  @override
  Widget build(BuildContext context) {
    int currentAssignedTotal = _currentMap.values.fold(0, (sum, v) => sum + v);
    int remaining = widget.maxQty - currentAssignedTotal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'assign_quantities',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ).tr(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: remaining < 0
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: remaining < 0
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                "Left: $remaining / ${widget.maxQty}",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: remaining < 0 ? Colors.red : Colors.green[800],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.participants.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final p = widget.participants[index];
              final qty = _currentMap[p['id']] ?? 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: qty > 0 ? Colors.blue.withValues(alpha: 0.05) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: qty > 0 ? Colors.blue : Colors.grey.shade100,
                    width: 1.5,
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
                    const SizedBox(width: 16),
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
                            Icons.remove_circle_outline_rounded,
                            color: qty > 0 ? Colors.red : Colors.grey[300],
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 32),
                          alignment: Alignment.center,
                          child: Text(
                            "$qty",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
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
                            Icons.add_circle_outline_rounded,
                            color: remaining > 0 ? Colors.green : Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: remaining >= 0 ? () => widget.onConfirm(_currentMap) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'confirm_quantities',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ).tr(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
