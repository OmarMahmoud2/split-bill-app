import 'package:split_bill_app/screens/split_bill/widgets/add_people_screen.dart';
import 'package:split_bill_app/services/group_service.dart';

/// The host's groups as [AddPeopleGroup]s (for `AddPeopleScreen`).
Stream<List<AddPeopleGroup>> addPeopleGroupsFrom(GroupService service) =>
    service.getMyGroups().map(
      (snapshot) => [
        for (final doc in snapshot.docs)
          if (doc.data() is Map)
            _groupFrom(doc.id, Map<String, dynamic>.from(doc.data() as Map)),
      ],
    );

AddPeopleGroup _groupFrom(String id, Map<String, dynamic> data) =>
    AddPeopleGroup(
      id: id,
      name: (data['name'] ?? '').toString(),
      members: [
        for (final m in (data['members'] as List?) ?? const [])
          if (m is Map && m['id'] != null) Map<String, dynamic>.from(m),
      ],
    );
