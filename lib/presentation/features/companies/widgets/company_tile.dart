import 'package:flutter/material.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import '../company_view_panel.dart';

class CompanyTile extends StatelessWidget {
  final Company company;
  const CompanyTile({super.key, required this.company});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => showRightDrawer(
        context,
        child: CompanyViewPanel(companyId: company.id),
        widthFraction: 0.86,
        heightFraction: 0.96,
      ),
      leading: const CircleAvatar(child: Icon(Icons.business)),
      title: Text(company.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(company.code),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'view') {
            showRightDrawer(
              context,
              child: CompanyViewPanel(companyId: company.id),
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
