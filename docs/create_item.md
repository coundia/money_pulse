Create  for this table unit :

- unit_list_page.dart: page orchestration (load/search/navigate + repo calls)
- unit_form_panel.dart: add/edit UI inside a right drawer
- unit_view_panel.dart:  UI inside a right drawer
- unit_delete_panel.dart: confirm delete inside a right drawer
- unit_tile.dart: reusable list tile
- unit_context_menu.dart: reusable menu model
- use unit_view_panel , add it menu context and use it when i click on a item
- always use right_drawer.dart for popup
- add provider  unit_repo_provider.dart
  <<
  final unitRepoProvider = Provider<unitRepository>((ref) {
    final db = ref.read(dbProvider);
    return unitRepositorySqflite(db);
  });
  >>
