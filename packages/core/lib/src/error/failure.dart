import 'package:equatable/equatable.dart';

/// Domain-level errors. Data sources translate exceptions into these so the
/// presentation layer never sees Dio or SQLite types.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexão com a internet.']);
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Serviço indisponível. Tente novamente.']);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Sua sessão expirou.']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Falha ao acessar os dados locais.']);
}
