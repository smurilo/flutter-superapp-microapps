/// Shared kernel of the super app. Micro apps depend only on these contracts,
/// never on each other.
library;

export 'src/database/app_database.dart';
export 'src/error/failure.dart';
export 'src/error/result.dart';
export 'src/events/app_events.dart';
export 'src/events/event_bus.dart';
export 'src/micro_app/micro_app.dart';
export 'src/micro_app/micro_app_registry.dart';
export 'src/network/api_client.dart';
export 'src/network/mock_backend_interceptor.dart';
