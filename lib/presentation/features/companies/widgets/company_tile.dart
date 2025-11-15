// Reusable company tile with publish state (badge + icon) and context menu entry point.
import 'package:flutter/material.dart';
import 'package:jaayko/domain/company/entities/company.dart';
import 'package:jaayko/presentation/widgets/right_drawer.dart';
import '../company_view_panel.dart';
import '../company_form_panel.dart';
import '../company_delete_panel.dart';
import 'company_context_menu.dart';

class CompanyTile extends StatelessWidget {
  final Company company;
  final VoidCallback? onActionDone;

  const CompanyTile({super.key, required this.company, this.onActionDone});

  bool get _isPublished {
    final s = (company.status ?? '').toUpperCase();
    return (s == 'PUBLISH' || s == 'PUBLISHED') && company.isPublic == true;
  }

  @override
  Widget build(BuildContext context) {
    final badge = Chip(
      label: Text(_isPublished ? 'Publié' : 'Non publié'),
      avatar: Icon(
        _isPublished ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        size: 18,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return ListTile(
      onTap: () async {
        final res = await showRightDrawer<bool>(
          context,
          child: CompanyViewPanel(companyId: company.id),
          widthFraction: 0.86,
          heightFraction: 0.96,
        );
        if (res == true) {
          onActionDone?.call();
        }
      },
      leading: const CircleAvatar(child: Icon(Icons.business)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              company.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _isPublished ? 'Publié' : 'Non publié',
            child: Icon(
              _isPublished
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              size: 18,
            ),
          ),
        ],
      ),

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
