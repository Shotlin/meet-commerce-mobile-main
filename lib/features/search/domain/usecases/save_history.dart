import 'package:bakaloo_flutter_app/features/search/domain/repositories/search_repository.dart';

class SaveHistoryUseCase {
  const SaveHistoryUseCase(this._repository);

  final SearchRepository _repository;

  Future<void> call(String query) {
    return _repository.saveHistory(query);
  }
}
