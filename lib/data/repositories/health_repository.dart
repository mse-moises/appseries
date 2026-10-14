import '../../utils/result.dart';
import '../api_models/health_status.dart';

/// Contract of the health resource.
///
/// The ViewModel depends on **this**, never on [HealthRepositoryImpl] — that is
/// what lets a test pass a fake and what lets a cached/offline implementation
/// come later without touching any screen.
abstract class HealthRepository {
  Future<Result<HealthStatus>> check();
}
