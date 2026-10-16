import 'package:equatable/equatable.dart';

/// Events that cross micro app boundaries. Payloads are primitives only, so the
/// publisher's domain classes never leak into the subscriber.
sealed class AppEvent extends Equatable {
  const AppEvent();
}

final class PixSentEvent extends AppEvent {
  const PixSentEvent({required this.endToEndId, required this.amountInCents, required this.recipientName});

  final String endToEndId;
  final int amountInCents;
  final String recipientName;

  @override
  List<Object?> get props => [endToEndId, amountInCents, recipientName];
}

final class SessionExpiredEvent extends AppEvent {
  const SessionExpiredEvent();

  @override
  List<Object?> get props => const [];
}
