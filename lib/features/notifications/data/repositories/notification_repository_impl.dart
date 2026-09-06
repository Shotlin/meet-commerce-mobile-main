import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/notifications/data/models/notification_model.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_preference_entity.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl({
    required NotificationRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final NotificationRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, NotificationsPageEntity>> getNotifications({
    required int page,
    required int limit,
  }) async {
    try {
      final response = await _remoteDataSource.getNotifications(
        page: page,
        limit: limit,
      );
      return Right(
        NotificationsPageEntity(
          items: response.items.map((item) => item.toEntity()).toList(
                growable: false,
              ),
          pagination: response.pagination,
          unreadCount: response.unreadCount,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load notifications right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> markRead(String notificationId) async {
    try {
      await _remoteDataSource.markRead(notificationId);
      return const Right(unit);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to mark notification as read.'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> markAllRead() async {
    try {
      await _remoteDataSource.markAllRead();
      return const Right(unit);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to mark all notifications as read.'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> markCampaignOpened(String campaignId) async {
    try {
      await _remoteDataSource.markCampaignOpened(campaignId);
      return const Right(unit);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to record notification open.'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteNotification(
    String notificationId,
  ) async {
    try {
      await _remoteDataSource.deleteNotification(notificationId);
      return const Right(unit);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to delete notification right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, NotificationPreferenceEntity>> getPreferences() async {
    try {
      final preferences = await _remoteDataSource.getPreferences();
      return Right(preferences.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to load notification preferences right now.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> registerFcmToken({
    required String token,
    required String platform,
  }) async {
    try {
      await _remoteDataSource.registerFcmToken(
        token: token,
        platform: platform,
      );
      return const Right(unit);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to register notification token.'),
      );
    }
  }

  @override
  Future<Either<Failure, NotificationPreferenceEntity>> updatePreferences(
    NotificationPreferenceEntity preferences,
  ) async {
    try {
      final payload = NotificationPreferenceModel.fromEntity(preferences);
      final updated = await _remoteDataSource.updatePreferences(payload);
      return Right(updated.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to update notification preferences right now.',
        ),
      );
    }
  }
}
