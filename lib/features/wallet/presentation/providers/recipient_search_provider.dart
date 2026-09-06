import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/utils/debouncer.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_recipient_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';

part 'recipient_search_provider.g.dart';

/// Matches the backend's recipient-search prefix constraint
/// (`^[6-9]\d{5,9}$`) — a 6-10 digit Indian mobile number prefix. Shorter
/// input just keeps the result list empty rather than firing a request
/// that would be rejected anyway.
final RegExp _validPrefix = RegExp(r'^[6-9]\d{5,9}$');

@riverpod
class RecipientSearchNotifier extends _$RecipientSearchNotifier {
  final Debouncer _debouncer = Debouncer(
    delay: const Duration(milliseconds: AppConstants.searchDebounceMs),
  );

  String _currentQuery = '';

  @override
  Future<List<WalletRecipientEntity>> build() {
    ref.onDispose(_debouncer.dispose);
    return Future<List<WalletRecipientEntity>>.value(
      const <WalletRecipientEntity>[],
    );
  }

  void onQueryChanged(String query) {
    final trimmedQuery = query.trim();
    _currentQuery = trimmedQuery;

    if (!_validPrefix.hasMatch(trimmedQuery)) {
      _debouncer.cancel();
      state = const AsyncData<List<WalletRecipientEntity>>(
        <WalletRecipientEntity>[],
      );
      return;
    }

    state = const AsyncLoading<List<WalletRecipientEntity>>();
    _debouncer.run(() {
      unawaited(_search(trimmedQuery));
    });
  }

  Future<void> _search(String query) async {
    final result = await ref.read(searchRecipientUseCaseProvider).call(query);

    if (query != _currentQuery) {
      return;
    }

    state = result.fold(
      (failure) => AsyncError<List<WalletRecipientEntity>>(
        StateError(failure.message),
        StackTrace.current,
      ),
      (recipients) => AsyncData<List<WalletRecipientEntity>>(recipients),
    );
  }
}
