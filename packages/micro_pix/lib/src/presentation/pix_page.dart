import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'pix_cubit.dart';

class PixPage extends StatelessWidget {
  const PixPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pix')),
      body: BlocBuilder<PixCubit, PixState>(
        builder: (context, state) {
          final cubit = context.read<PixCubit>();
          final receipt = state.receipt;
          if (receipt != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: DsColors.credit, size: 72),
                  Text('Pix enviado!', style: Theme.of(context).textTheme.headlineSmall),
                  Text('${Money.format(receipt.amountInCents)} para ${receipt.recipientName}'),
                  Text('ID ${receipt.endToEndId}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: cubit.reset, child: const Text('Novo Pix')),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'CPF, CNPJ, e-mail, celular ou chave aleatória',
                  errorText: state.keyError,
                  helperText: state.key == null ? null : 'Chave ${state.key!.label}',
                ),
                onChanged: cubit.keyChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(labelText: r'Valor (R$)', errorText: state.amountError),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: cubit.amountChanged,
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.canSubmit ? cubit.submit : null,
                child: state.sending
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Transferir'),
              ),
            ],
          );
        },
      ),
    );
  }
}
