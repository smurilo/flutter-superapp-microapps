import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'statement_cubit.dart';

class StatementPage extends StatelessWidget {
  const StatementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extrato')),
      body: BlocBuilder<StatementCubit, StatementState>(
        builder: (context, state) => switch (state) {
          StatementLoading() => const Center(child: CircularProgressIndicator()),
          StatementFailure(:final message) =>
            ErrorView(message: message, onRetry: () => context.read<StatementCubit>().load()),
          StatementLoaded() => RefreshIndicator(
              onRefresh: () => context.read<StatementCubit>().load(forceRefresh: true),
              child: ListView(
                children: [
                  if (state.statement.isStale)
                    const MaterialBanner(
                      content: Text('Sem conexão. Exibindo o último extrato salvo.'),
                      leading: Icon(Icons.wifi_off),
                      actions: [SizedBox.shrink()],
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: BalanceCard(
                      holder: state.statement.account.holder,
                      balanceInCents: state.statement.account.balanceInCents,
                    ),
                  ),
                  for (final entry in state.byDay.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(Dates.dayHeader(entry.key), style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final t in entry.value)
                      ListTile(
                        title: Text(t.title),
                        subtitle: Text(Dates.time(t.date)),
                        trailing: AmountText(t.amountInCents),
                      ),
                  ],
                ],
              ),
            ),
        },
      ),
    );
  }
}
