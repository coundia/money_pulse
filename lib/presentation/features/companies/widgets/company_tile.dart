import 'package:flutter/material.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import '../company_view_panel.dart';
import '../company_form_panel.dart';
import '../company_delete_panel.dart';
import 'company_context_menu.dart';

class CompanyTile extends StatelessWidget {
  final Company company;
  final VoidCallback? onActionDone; // NEW

  const CompanyTile({super.key, required this.company, this.onActionDone});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () async {
        final res = await showRightDrawer<bool>(
          context,
          child: CompanyViewPanel(companyId: company.id),
          widthFraction: 0.86,
          heightFraction: 0.96,
        );
        if (res == true) {
          onActionDone?.call(); // ex: suppression depuis la vue
        }
      },
      leading: const CircleAvatar(child: Icon(Icons.business)),
      title: Text(company.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(company.code),
      trailing: CompanyContextMenu(
        onSelected: (a) async {
          switch (a) {
            case CompanyMenuAction.view:
              final res = await showRightDrawer<bool>(
                context,
                child: CompanyViewPanel(companyId: company.id),
                widthFraction: 0.86,
                heightFraction: 0.96,
              );
              if (res == true) onActionDone?.call();
              break;
            case CompanyMenuAction.edit:
              final ok = await showRightDrawer<bool>(
                context,
                child: CompanyFormPanel(initial: company),
                widthFraction: 0.86,
                heightFraction: 0.96,
              );
              if (ok == true) onActionDone?.call();
              break;
            case CompanyMenuAction.delete:
              final ok = await showRightDrawer<bool>(
                context,
                child: CompanyDeletePanel(companyId: company.id),
                widthFraction: 0.86,
                heightFraction: 0.6,
              );
              if (ok == true) onActionDone?.call();
              break;
          }
        },
      ),
    );
  }
}
