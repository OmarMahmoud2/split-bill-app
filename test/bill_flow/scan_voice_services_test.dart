import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_bill_app/services/bill_intelligence_service.dart';
import 'package:split_bill_app/services/receipt_service.dart';

http.Response json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('receipt scan', () {
    final service = ReceiptService(tokenProvider: () async => null);

    test('422 non-receipt is friendly and refunded', () {
      expect(
        () => service.parseScanResponse(
          json(422, {'errorCode': 'not_a_receipt', 'error': 'menu'}),
        ),
        throwsA(
          isA<ReceiptScanException>()
              .having((e) => e.failure, 'failure', ReceiptScanFailure.notAReceipt)
              .having((e) => e.refunded, 'refunded', isTrue)
              .having((e) => e.errorCode, 'code', 'not_a_receipt'),
        ),
      );
    });

    test('413 and 415 map to size and format', () {
      expect(
        classifyScanError(413, const {}).failure,
        ReceiptScanFailure.tooLarge,
      );
      expect(
        classifyScanError(415, const {}).failure,
        ReceiptScanFailure.unsupportedFormat,
      );
      expect(
        classifyScanError(504, const {}).failure,
        ReceiptScanFailure.timeout,
      );
    });

    test('non-JSON error page does not leak raw text', () {
      expect(
        () => service.parseScanResponse(http.Response('<html>', 502)),
        throwsA(
          isA<ReceiptScanException>().having(
            (e) => e.failure,
            'failure',
            ReceiptScanFailure.timeout,
          ),
        ),
      );
    });

    test('keeps review reasons and reconciliation', () {
      final r = service.parseScanResponse(
        json(200, {
          'requestId': 'r1',
          'receipt': {
            'items': [
              {'name': 'Kunafa', 'price': 7, 'qty': 1},
            ],
            'needs_review_reasons': ['blurry_item'],
          },
          'reconciliation': {'printed_total': 81.27, 'matches': true},
        }),
      );
      expect(r['needs_review_reasons'], ['blurry_item']);
      expect(r['needs_review'], isTrue);
      expect(r['reconciliation'], {'printed_total': 81.27, 'matches': true});
      expect(r['requestId'], 'r1');
    });
  });

  group('voice assign', () {
    test('sends requestId, currentUserId, aliases, transcriptSource', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.headers['X-Request-Id'], 'req-1');
        return json(200, {
          'assignments': {
            '0': ['a'],
          },
          'splits': {
            '1': {'a': 2, 'b': 1},
          },
          'unassignedItemKeys': ['2'],
          'ambiguous': [
            {'itemKey': '2', 'text': 'the mint drinks'},
          ],
        });
      });
      final service = BillIntelligenceService(
        client: client,
        tokenProvider: () async => 'tok',
        requestIdFactory: () => 'req-1',
      );
      final result = await service.assignItemsByVoice(
        receiptItems: const [
          {'name': 'Burger', 'price': 14, 'qty': 1},
          {'name': 'Mint', 'price': 3, 'qty': 3},
          {'name': 'Kunafa', 'price': 7, 'qty': 1},
        ],
        participants: const [
          {'id': 'a', 'name': 'Ali'},
          {'id': 'b', 'name': 'Sara'},
        ],
        transcript: 'Ali had the burger',
        currentUserId: 'a',
        aliases: const {
          'a': ['me', 'I'],
        },
      );
      expect(sent['requestId'], 'req-1');
      expect(sent['currentUserId'], 'a');
      expect(sent['transcriptSource'], 'on_device');
      expect(sent['aliases'], {
        'a': ['me', 'I'],
      });
      expect((sent['receiptItems'] as List).first['key'], '0');
      expect(result.assignments['0'], ['a']);
      expect(result.splits['1'], {'a': 2, 'b': 1});
      expect(result.unassignedItemKeys, ['2']);
      expect(result.ambiguous.single.text, 'the mint drinks');
    });

    test('errors are typed, not raw', () {
      final service = BillIntelligenceService(tokenProvider: () async => null);
      expect(
        () => service.parseAssignResponse(json(402, {'error': 'x'})),
        throwsA(
          isA<VoiceAssignException>().having(
            (e) => e.failure,
            'failure',
            VoiceAssignFailure.noCredits,
          ),
        ),
      );
    });

    test('tolerates list-shaped splits', () {
      final r = VoiceAssignResult.fromJson({
        'splits': [
          {'itemKey': '1', 'participantId': 'a', 'units': 2},
          {
            'itemKey': '1',
            'units': {'b': 1},
          },
        ],
      });
      expect(r.splits['1'], {'a': 2, 'b': 1});
      expect(r.assignments, isEmpty);
    });
  });
}
