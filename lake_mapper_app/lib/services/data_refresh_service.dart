import 'package:flutter/material.dart';

/// Simple global notifier to trigger data refreshes across tabs.
/// Used because IndexedStack keeps screens alive but doesn't rebuild them.
class DataRefreshService extends ChangeNotifier {
  static final DataRefreshService instance = DataRefreshService._internal();
  DataRefreshService._internal();

  void refresh() {
    notifyListeners();
  }
}
