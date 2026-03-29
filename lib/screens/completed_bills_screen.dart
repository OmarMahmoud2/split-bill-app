import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_bill_app/widgets/bill_tile.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:easy_localization/easy_localization.dart';

class CompletedBillsScreen extends StatefulWidget {
  const CompletedBillsScreen({super.key});

  @override
  State<CompletedBillsScreen> createState() => _CompletedBillsScreenState();
}

class _CompletedBillsScreenState extends State<CompletedBillsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  List<QueryDocumentSnapshot> _filterCompletedBills(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (user == null) return [];

    // Sort by date descending
    docs.sort((a, b) {
      Timestamp tA = (a.data() as Map)['date'] ?? Timestamp.now();
      Timestamp tB = (b.data() as Map)['date'] ?? Timestamp.now();
      return tB.compareTo(tA);
    });

    return docs.where((doc) {
      try {
        var data = doc.data() as Map<String, dynamic>? ?? {};
        if (!data.containsKey('hostId') || !data.containsKey('participants')) {
          return false;
        }

        bool amIHost = data['hostId'] == user!.uid;
        List parts = data['participants'] ?? [];

        // Determine Settled Status
        bool isSettled = false;
        if (amIHost) {
          // Host: Settled if ALL participants (including host) have paid
          bool anyPending = parts.any(
            (p) => p['status'] == 'PENDING' || p['status'] == 'REVIEW',
          );
          isSettled = !anyPending;
        } else {
          // Participant: Settled if I paid
          var me = parts.firstWhere(
            (p) => p['id'] == user!.uid,
            orElse: () => null,
          );
          isSettled = (me != null && me['status'] == 'PAID');
        }

        // Return only Completed bills
        return isSettled && data['status'] != 'UNATTEMPTED';
      } catch (e) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(body: Center(child: Text('please_log_in').tr()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bills')
            .where('participants_uids', arrayContains: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingStateWidget(message: 'loading_history'.tr());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'error_with_details'.tr(
                  namedArgs: {'error': snapshot.error.toString()},
                ),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];
          final filteredDocs = _filterCompletedBills(allDocs);

          return CustomScrollView(
            slivers: [
              // 1. HEADER
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text('completed_bills',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ).tr(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. LIST OR EMPTY STATE
              if (filteredDocs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/animations/empty.json',
                          height: 150,
                          repeat: false,
                        ),
                        const SizedBox(height: 16),
                        Text('no_completed_bills_yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ).tr(),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return BillTile(
                        data:
                            filteredDocs[index].data() as Map<String, dynamic>,
                        billId: filteredDocs[index].id,
                        currentUserId: user!.uid,
                      );
                    }, childCount: filteredDocs.length),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          );
        },
      ),
    );
  }
}
