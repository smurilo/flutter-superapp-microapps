import 'package:flutter/material.dart';

import 'formatters.dart';
import 'theme.dart';

/// Balance card with "hide values" toggle, common in Brazilian banking apps.
class BalanceCard extends StatefulWidget {
  const BalanceCard({required this.holder, required this.balanceInCents, super.key});

  final String holder;
  final int balanceInCents;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final text = _hidden ? r'R$ ••••••' : Money.format(widget.balanceInCents);
    return Card(
      color: DsColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Olá, ${widget.holder}', style: const TextStyle(color: Colors.white70)),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: _hidden ? 'Saldo oculto' : 'Saldo $text',
                    excludeSemantics: true,
                    child: Text(text,
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                ),
                IconButton(
                  tooltip: _hidden ? 'Mostrar saldo' : 'Ocultar saldo',
                  color: Colors.white,
                  icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AmountText extends StatelessWidget {
  const AmountText(this.cents, {super.key});

  final int cents;

  @override
  Widget build(BuildContext context) => Text(
        Money.format(cents),
        style: TextStyle(color: cents >= 0 ? DsColors.credit : DsColors.debit, fontWeight: FontWeight.w600),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
}
