import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// One amount the reader can give. [id] is the Play Console product id.
class DonationOption {
  final String id;
  final String price; // already formatted by the store, e.g. "₩2,000"
  const DonationOption({required this.id, required this.price});
}

/// What the store said about one purchase attempt.
enum DonationEvent { thanked, failed, cancelled }

/// The store, behind a seam, so the screen and the service can be tested on
/// the PC. The real one talks to Google Play; the tests use a fake.
abstract class DonationGateway {
  Future<bool> isAvailable();

  /// Products found for [ids], in the order of [ids]. Unknown ids are left
  /// out, which is what happens until they exist in the Play Console.
  Future<List<DonationOption>> products(List<String> ids);

  Future<bool> buy(String id);

  /// Results of purchases, including ones finished while the app was closed.
  Stream<DonationEvent> get events;

  void dispose();
}

/// Google Play billing. Tips are consumables, so a reader can give again.
class PlayDonationGateway implements DonationGateway {
  final InAppPurchase _iap = InAppPurchase.instance;
  final _events = StreamController<DonationEvent>.broadcast();
  final Map<String, ProductDetails> _details = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;

  PlayDonationGateway() {
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {
      _events.add(DonationEvent.failed);
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Nothing is unlocked, so there is nothing to verify: a tip is a
          // tip. It only has to be acknowledged, or Play refunds it.
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _events.add(DonationEvent.thanked);
        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _events.add(DonationEvent.cancelled);
        case PurchaseStatus.error:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _events.add(DonationEvent.failed);
      }
    }
  }

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<DonationOption>> products(List<String> ids) async {
    final r = await _iap.queryProductDetails(ids.toSet());
    for (final d in r.productDetails) {
      _details[d.id] = d;
    }
    return [
      for (final id in ids)
        if (_details[id] != null)
          DonationOption(id: id, price: _details[id]!.price),
    ];
  }

  @override
  Future<bool> buy(String id) {
    final d = _details[id];
    if (d == null) return Future.value(false);
    return _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: d));
  }

  @override
  Stream<DonationEvent> get events => _events.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _events.close();
  }
}

enum DonationState { loading, ready, unavailable }

/// Drives the donation sheet. The store is only touched once the sheet opens,
/// so a reader who never looks at it never starts Play billing.
class DonationService extends ChangeNotifier {
  /// Created in the Play Console as managed (consumable) products.
  static const productIds = ['tip_small', 'tip_medium', 'tip_large'];

  final DonationGateway _gateway;
  StreamSubscription<DonationEvent>? _sub;

  DonationState state = DonationState.loading;
  List<DonationOption> options = const [];
  bool buying = false;

  /// Last outcome, for the screen to show once and clear.
  DonationEvent? lastEvent;

  bool _disposed = false;

  DonationService(this._gateway) {
    _sub = _gateway.events.listen((e) {
      buying = false;
      lastEvent = e;
      _notify();
    });
  }

  Future<void> load() async {
    state = DonationState.loading;
    _notify();
    try {
      if (!await _gateway.isAvailable()) {
        state = DonationState.unavailable;
      } else {
        options = await _gateway.products(productIds);
        state = options.isEmpty
            ? DonationState.unavailable
            : DonationState.ready;
      }
    } catch (_) {
      state = DonationState.unavailable;
    }
    _notify();
  }

  Future<void> buy(DonationOption o) async {
    if (buying) return;
    buying = true;
    lastEvent = null;
    _notify();
    bool started = false;
    try {
      started = await _gateway.buy(o.id);
    } catch (_) {
      started = false;
    }
    if (!started) {
      buying = false;
      lastEvent = DonationEvent.failed;
      _notify();
    }
  }

  void clearEvent() => lastEvent = null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _gateway.dispose();
    super.dispose();
  }
}
