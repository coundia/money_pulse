// Compact customer list tile with balance pills and context menu; opens right drawers and reports changes.
import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import '../customer_view_panel.dart';
import '../customer_form_panel.dart';
import '../customer_delete_panel.dart';

class CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onChanged;
  const CustomerTile({super.key, required this.customer, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final subtitleLine = (customer.phone ?? '').isNotEmpty
        ? customer.phone!
        : (customer.email ?? '');
    final colorDanger = Theme.of(context).colorScheme.error;
    final colorPrimary = Theme.of(context).colorScheme.primary;

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      minLeadingWidth: 36,
      leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
      title: Text(
        customer.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              subtitleLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _Pill(label: 'Solde', cents: customer.balance, color: colorPrimary),
          const SizedBox(width: 6),
          _Pill(
            label: 'Dette',
            cents: customer.balanceDebt,
            color: colorDanger,
          ),
        ],
      ),
      onTap: () async {
        final ok = await showRightDrawer<bool>(
          context,
          child: CustomerViewPanel(customerId: customer.id),
          widthFraction: 0.86,
          heightFraction: 0.96,
        );
        if (ok == true) onChanged?.call();
      },
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'view':
              final ok = await showRightDrawer<bool>(
                context,
                child: CustomerViewPanel(customerId: customer.id),
                widthFraction: 0.86,
                heightFraction: 0.96,
              );
              if (ok == true) onChanged?.call();
              break;
            case 'edit':
              final ok = await showRightDrawer<bool>(
                context,
                child: CustomerFormPanel(initial: customer),
                widthFraction: 0.86,
                heightFraction: 0.96,
              );
              if (ok == true) onChanged?.call();
              break;
            case 'delete':
              final ok = await showRightDrawer<bool>(
                context,
                child: CustomerDeletePanel(customerId: customer.id),
                widthFraction: 0.86,
                heightFraction: 0.6,
              );
              if (ok == true) onChanged?.call();
              break;
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'view', child: Text('Voir')),
          PopupMenuItem(value: 'edit', child: Text('Modifier')),
          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final int cents;
  final Color color;
  const _Pill({required this.label, required this.cents, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: Formatters.amountFromCents(cents),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          Formatters.amountFromCents(cents),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
