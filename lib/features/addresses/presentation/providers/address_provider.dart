import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/features/addresses/data/datasources/address_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/addresses/data/repositories/address_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/create_address_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/delete_address_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/get_addresses_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/set_default_address_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/update_address_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/validate_pincode_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/confirmation_dialog.dart';

part 'address_provider.g.dart';

final addressRemoteDataSourceProvider = Provider<AddressRemoteDataSource>((
  Ref ref,
) {
  return AddressRemoteDataSource(ref.watch(apiClientProvider));
});

final addressRepositoryProvider = Provider<AddressRepository>((Ref ref) {
  final authState = ref.watch(authStateProvider);
  final fallbackName = switch (authState) {
    AuthAuthenticated(:final user)
        when user.name != null && user.name!.trim().isNotEmpty =>
      user.name!.trim(),
    _ => 'Bakaloo Customer',
  };
  final fallbackPhone = switch (authState) {
    AuthAuthenticated(:final user) => user.phone,
    _ => '',
  };

  return AddressRepositoryImpl(
    remoteDataSource: ref.watch(addressRemoteDataSourceProvider),
    fallbackName: fallbackName,
    fallbackPhone: fallbackPhone,
  );
});

final getAddressesUseCaseProvider = Provider<GetAddressesUseCase>((Ref ref) {
  return GetAddressesUseCase(ref.watch(addressRepositoryProvider));
});

final createAddressUseCaseProvider = Provider<CreateAddressUseCase>((Ref ref) {
  return CreateAddressUseCase(ref.watch(addressRepositoryProvider));
});

final updateAddressUseCaseProvider = Provider<UpdateAddressUseCase>((Ref ref) {
  return UpdateAddressUseCase(ref.watch(addressRepositoryProvider));
});

final deleteAddressUseCaseProvider = Provider<DeleteAddressUseCase>((Ref ref) {
  return DeleteAddressUseCase(ref.watch(addressRepositoryProvider));
});

final setDefaultAddressUseCaseProvider =
    Provider<SetDefaultAddressUseCase>((Ref ref) {
  return SetDefaultAddressUseCase(ref.watch(addressRepositoryProvider));
});

final validatePincodeUseCaseProvider =
    Provider<ValidatePincodeUseCase>((Ref ref) {
  return ValidatePincodeUseCase(ref.watch(addressRepositoryProvider));
});

class AddressActionResult {
  const AddressActionResult({
    this.failure,
    this.cancelled = false,
  });

  final Failure? failure;
  final bool cancelled;

  bool get isSuccess => failure == null && !cancelled;
}

@riverpod
class AddressNotifier extends _$AddressNotifier {
  @override
  Future<List<AddressEntity>> build() async {
    // Cache-then-network: an address rarely changes between app opens, so a
    // cold start shows the last-known list instantly (matching the pattern
    // already used for theme/home content in remote_theme_provider.dart)
    // instead of leaving the screen blank for an entire network round trip.
    // A background refresh still runs and silently corrects the screen if
    // anything actually changed — order placement always re-resolves the
    // address by id server-side (see checkout_provider.dart), so a
    // momentarily-stale cached list here can never cause a wrong delivery.
    final cached = _readCachedAddresses();
    if (cached != null) {
      debugPrint(
        '[AddressNotifier] served ${cached.length} address(es) from cache '
        'at t=${DateTime.now()}; refreshing in background',
      );
      unawaited(_refreshInBackground());
      return cached;
    }

    final result = await ref.read(getAddressesUseCaseProvider).call();
    return result.fold(
      (failure) => throw StateError(failure.message),
      (addresses) {
        final sorted = _sortAddresses(addresses);
        _writeCache(sorted);
        return sorted;
      },
    );
  }

  /// Re-fetches in the background after serving a cached list from [build].
  /// Only touches `state` if the notifier is still alive and the result
  /// actually differs from what's cached, so a silent no-op refresh never
  /// causes a pointless rebuild.
  Future<void> _refreshInBackground() async {
    final result = await ref.read(getAddressesUseCaseProvider).call();
    result.fold(
      (failure) {
        debugPrint('[AddressNotifier] background refresh failed: '
            '${failure.message}');
      },
      (addresses) {
        final sorted = _sortAddresses(addresses);
        if (!ref.mounted) {
          return;
        }
        if (!listEquals(_currentAddresses, sorted)) {
          state = AsyncData(sorted);
        }
        _writeCache(sorted);
      },
    );
  }

  List<AddressEntity>? _readCachedAddresses() {
    try {
      final raw = HiveService.settingsBox.get(StorageKeys.cacheAddresses);
      if (raw is! String || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }
      return decoded
          .whereType<Map>()
          .map((item) => _addressFromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (error) {
      debugPrint('[AddressNotifier] cache read failed: $error');
      return null;
    }
  }

  void _writeCache(List<AddressEntity> addresses) {
    try {
      final encoded = jsonEncode(
        addresses.map(_addressToJson).toList(growable: false),
      );
      unawaited(
        HiveService.settingsBox.put(StorageKeys.cacheAddresses, encoded),
      );
    } catch (error) {
      debugPrint('[AddressNotifier] cache write failed: $error');
    }
  }

  Future<AddressActionResult> createAddress(AddressUpsertParams params) async {
    final result = await ref.read(createAddressUseCaseProvider).call(params);

    return result.fold(
      (failure) => AddressActionResult(failure: failure),
      (address) {
        final next = _sortAddresses(<AddressEntity>[
          ..._currentAddresses.where((item) => item.id != address.id),
          address,
        ]);
        state = AsyncData(next);
        _writeCache(next);
        ref.invalidateSelf();
        return const AddressActionResult();
      },
    );
  }

  Future<AddressActionResult> updateAddress(
    String id,
    AddressUpsertParams params,
  ) async {
    final result =
        await ref.read(updateAddressUseCaseProvider).call(id, params);

    return result.fold(
      (failure) => AddressActionResult(failure: failure),
      (address) {
        final next = _sortAddresses(
          _currentAddresses
              .map((item) => item.id == id ? address : item)
              .toList(growable: false),
        );
        state = AsyncData(next);
        _writeCache(next);
        return const AddressActionResult();
      },
    );
  }

  Future<AddressActionResult> deleteAddress(
    BuildContext context,
    String id,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete address?',
      message: 'This saved address will be removed from your account.',
      confirmLabel: 'Delete',
    );

    if (confirmed != true) {
      return const AddressActionResult(cancelled: true);
    }

    final result = await ref.read(deleteAddressUseCaseProvider).call(id);

    return result.fold(
      (failure) => AddressActionResult(failure: failure),
      (_) {
        final next = _sortAddresses(
          _currentAddresses
              .where((item) => item.id != id)
              .toList(growable: false),
        );
        state = AsyncData(next);
        _writeCache(next);
        return const AddressActionResult();
      },
    );
  }

  Future<AddressActionResult> setDefault(String id) async {
    final previous = _currentAddresses;
    final optimistic = _sortAddresses(
      previous
          .map(
            (item) => item.copyWith(
              isDefault: item.id == id,
            ),
          )
          .toList(growable: false),
    );
    state = AsyncData(optimistic);

    final result = await ref.read(setDefaultAddressUseCaseProvider).call(id);

    return result.fold(
      (failure) {
        state = AsyncData(previous);
        return AddressActionResult(failure: failure);
      },
      (address) {
        final next = _sortAddresses(
          previous
              .map(
                (item) => item.id == id
                    ? address.copyWith(isDefault: true)
                    : item.copyWith(isDefault: false),
              )
              .toList(growable: false),
        );
        state = AsyncData(next);
        _writeCache(next);
        return const AddressActionResult();
      },
    );
  }

  void refresh() {
    ref.invalidateSelf();
  }

  List<AddressEntity> get _currentAddresses => switch (state) {
        AsyncData(:final value) => value,
        _ => const <AddressEntity>[],
      };

  List<AddressEntity> _sortAddresses(List<AddressEntity> addresses) {
    return addresses.toList(growable: true)
      ..sort((a, b) {
        if (a.isDefault == b.isDefault) {
          return a.label.compareTo(b.label);
        }
        return a.isDefault ? -1 : 1;
      });
  }
}

/// Hand-written (no codegen) JSON mapping for the on-device address cache.
/// [AddressEntity] itself has no `toJson`/`fromJson` — it's a plain freezed
/// value type — so this mirrors it field-for-field rather than pulling in
/// build_runner just for local cache persistence.
Map<String, dynamic> _addressToJson(AddressEntity address) => <String, dynamic>{
      'id': address.id,
      'label': address.label,
      'name': address.name,
      'phone': address.phone,
      'addressLine1': address.addressLine1,
      'addressLine2': address.addressLine2,
      'city': address.city,
      'state': address.state,
      'pincode': address.pincode,
      'latitude': address.latitude,
      'longitude': address.longitude,
      'receiverName': address.receiverName,
      'receiverPhone': address.receiverPhone,
      'isDefault': address.isDefault,
    };

AddressEntity _addressFromJson(Map<String, dynamic> json) => AddressEntity(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Other',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      addressLine1: json['addressLine1'] as String? ?? '',
      addressLine2: json['addressLine2'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      receiverName: json['receiverName'] as String?,
      receiverPhone: json['receiverPhone'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
