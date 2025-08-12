import 'package:flutter/material.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import '../customer_view_panel.dart';

class CustomerTile extends StatelessWidget {
  final Customer customer;
  const CustomerTile({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => showRightDrawer(
        context,
        child: CustomerViewPanel(customerId: customer.id),
        widthFraction: 0.86,
        heightFraction: 0.96,
      ),
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
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'view') {
            showRightDrawer(
              context,
              child: CustomerViewPanel(customerId: customer.id),
              widthFraction: 0.86,
              heightFraction: 0.96,
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'view', child: Text('Voir')),
        ],
      ),
    );
  }
}
