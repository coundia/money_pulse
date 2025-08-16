// Customer tile with long-press contextual menu to run all actions, responsive and list refresh.
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../customer_view_panel.dart';
import '../customer_form_panel.dart';
import '../customer_delete_panel.dart';
import '../widgets/customer_balance_adjust_panel.dart';

import '../providers/customer_list_providers.dart';
import '../providers/customer_detail_providers.dart';

class CustomerTile extends ConsumerWidget {
  final Customer customer;
  const CustomerTile({super.key, required this.customer});

  Future<void> _openView(BuildContext context, WidgetRef ref) async {
    final changed = await showRightDrawer<bool>(
      context,
      child: CustomerViewPanel(customerId: customer.id),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (changed == true) {
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
    }
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerFormPanel(initial: customer),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true) {
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Client mis à jour')));
      }
    }
  }

  Future<void> _openAdjustBalance(
    BuildContext context,
    WidgetRef ref, {
    required bool setMode,
  }) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerBalanceAdjustPanel(
        customerId: customer.id,
        currentBalanceCents: customer.balance,
        companyId: customer.companyId,
        mode: setMode ? 'set' : 'add',
      ),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true) {
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
    }
  }

  Future<void> _openDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerDeletePanel(customerId: customer.id),
      widthFraction: 0.86,
      heightFraction: 0.6,
    );
    if (ok == true) {
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Client supprimé')));
      }
    }
  }

  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset globalPos,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        overlay.size.width - globalPos.dx,
        overlay.size.height - globalPos.dy,
      ),
      items: const [
        PopupMenuItem(value: 'view', child: Text('Voir')),
        PopupMenuItem(value: 'edit', child: Text('Modifier')),
        PopupMenuItem(value: 'add_balance', child: Text('Ajouter au solde')),
        PopupMenuItem(value: 'set_balance', child: Text('Définir le solde')),
        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
      ],
    );

    switch (selected) {
      case 'view':
        await _openView(context, ref);
        break;
      case 'edit':
        await _openEdit(context, ref);
        break;
      case 'add_balance':
        await _openAdjustBalance(context, ref, setMode: false);
        break;
      case 'set_balance':
        await _openAdjustBalance(context, ref, setMode: true);
        break;
      case 'delete':
        await _openDelete(context, ref);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: ListTile(
        onTap: () => _openView(context, ref),
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(
          customer.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          (customer.phone ?? '').isNotEmpty
              ? customer.phone!
              : (customer.email ?? ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Solde: ${Formatters.amountFromCents(customer.balance)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Dette: ${Formatters.amountFromCents(customer.balanceDebt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
