import 'package:bakaloo_flutter_app/features/search/domain/repositories/search_repository.dart';

class ClearHistoryUseCase {
  const ClearHistoryUseCase(this._repository);

  final SearchRepository _repository;

  Future<void> call() {
    return _repository.clearHistory();
  }
}
