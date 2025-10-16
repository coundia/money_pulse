// Responsive quick actions grid with enhanced haptics, keyboard shortcuts, and accessibility semantics in French.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/marketplace/presentation/marketplace_page.dart';
import 'package:money_pulse/presentation/features/companies/company_list_page.dart';
import 'package:money_pulse/presentation/features/transactions/pages/transaction_list_page.dart';
import 'package:money_pulse/presentation/features/pos/pos_page.dart';
import 'package:money_pulse/presentation/features/settings/settings_page.dart';
import 'package:money_pulse/presentation/features/reports/report_page.dart';
import 'package:money_pulse/presentation/features/products/product_list_page.dart';
import 'package:money_pulse/presentation/features/customers/customer_list_page.dart';
import 'package:money_pulse/presentation/features/categories/category_list_page.dart';
import 'package:money_pulse/presentation/features/accounts/account_page.dart';
import 'package:money_pulse/presentation/features/stock/stock_level_list_page.dart';
import 'package:money_pulse/presentation/shared/haptics_util.dart';
import '../../chatbot/chatbot_page.dart';
import '../../chatbot/chatbot_provider.dart';

class SummaryQuickActions extends StatelessWidget {
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddIncome;
  final VoidCallback? onAddDebt;
  final VoidCallback? onAddRepayment;
  final VoidCallback? onAddLoan;

  final bool showExpenseButton;
  final bool showIncomeButton;
  final bool showDebtButton;
  final bool showRepaymentButton;
  final bool showLoanButton;

  final bool showNavShortcuts;
  final bool showNavTransactionsButton;
  final bool showNavPosButton;
  final bool showNavSettingsButton;

  final bool showNavSearchButton;
  final bool showNavStockButton;
  final bool showNavReportButton;
  final bool showNavProductsButton;
  final bool showNavCustomersButton;
  final bool showNavCategoriesButton;
  final bool showNavAccountsButton;

  final VoidCallback? onOpenTransactions;
  final VoidCallback? onOpenPos;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenStock;
  final VoidCallback? onOpenReport;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenCustomers;
  final VoidCallback? onOpenCategories;
  final VoidCallback? onOpenAccounts;

  final bool showNavMarketplaceButton;
  final bool showNavChatbotButton;

  final VoidCallback? onOpenMarketplace;
  final VoidCallback? onOpenChatbot;

  const SummaryQuickActions({
    super.key,
    required this.onAddExpense,
    required this.onAddIncome,
    this.onAddDebt,
    this.onAddRepayment,
    this.onAddLoan,
    this.showExpenseButton = true,
    this.showIncomeButton = true,
    this.showDebtButton = true,
    this.showRepaymentButton = true,
    this.showLoanButton = true,
    this.showNavShortcuts = true,
    this.showNavTransactionsButton = true,
    this.showNavPosButton = true,
    this.showNavSettingsButton = true,
    this.showNavSearchButton = false,
    this.showNavStockButton = false,
    this.showNavReportButton = false,
    this.showNavProductsButton = false,
    this.showNavCustomersButton = false,
    this.showNavCategoriesButton = false,
    this.showNavAccountsButton = false,
    this.onOpenTransactions,
    this.onOpenPos,
    this.onOpenSettings,
    this.onOpenSearch,
    this.onOpenStock,
    this.onOpenReport,
    this.onOpenProducts,
    this.onOpenCustomers,
    this.onOpenCategories,
    this.onOpenAccounts,
    this.showNavMarketplaceButton = false,
    this.showNavChatbotButton = false,
    this.onOpenMarketplace,
    this.onOpenChatbot,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final buttons = <Widget>[];

        if (showExpenseButton) {
          buttons.add(
            _btn(
              context,
              label: '+ Dépense',
              hint: 'Créer une dépense',
              icon: Icons.trending_down_rounded,
              tone: Theme.of(context).colorScheme.error,
              onTap: onAddExpense,
            ),
          );
        }
        if (showIncomeButton) {
          buttons.add(
            _btn(
              context,
              label: '+ Revenu',
              hint: 'Créer un revenu',
              icon: Icons.trending_up_rounded,
              tone: Theme.of(context).colorScheme.tertiary,
              onTap: onAddIncome,
            ),
          );
        }
        if (showDebtButton) {
          buttons.add(
            _btn(
              context,
              label: '+ Dette',
              hint: 'Enregistrer une dette',
              icon: Icons.receipt_long_rounded,
              tone: Theme.of(context).colorScheme.primary,
              onTap: onAddDebt,
            ),
          );
        }
        if (showRepaymentButton) {
          buttons.add(
            _btn(
              context,
              label: '+ Remboursement',
              hint: 'Enregistrer un remboursement',
              icon: Icons.payments_rounded,
              tone: Theme.of(context).colorScheme.primary,
              onTap: onAddRepayment,
            ),
          );
        }
        if (showLoanButton) {
          buttons.add(
            _btn(
              context,
              label: '+ Prêt',
              hint: 'Enregistrer un prêt',
              icon: Icons.account_balance_rounded,
              tone: Theme.of(context).colorScheme.secondary,
              onTap: onAddLoan,
            ),
          );
        }

        if (showNavShortcuts) {
          if (showNavPosButton) {
            buttons.add(
              _btn(
                context,
                label: 'POS',
                hint: 'Ouvrir le point de vente',
                icon: Icons.point_of_sale,
                tone: Theme.of(context).colorScheme.secondary,
                onTap:
                    onOpenPos ??
                    () {
                      HapticsUtil.select();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PosPage()),
                      );
                    },
              ),
            );
          }
          if (showNavSettingsButton) {
            buttons.add(
              _btn(
                context,
                label: 'Paramètres',
                hint: 'Ouvrir les paramètres',
                icon: Icons.settings,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenSettings ??
                    () {
                      HapticsUtil.select();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
              ),
            );
          }
          if (showNavSearchButton) {
            buttons.add(
              _btn(
                context,
                label: 'Recherche',
                hint: 'Lancer une recherche',
                icon: Icons.search_rounded,
                tone: Theme.of(context).colorScheme.primary,
                onTap: () {
                  HapticsUtil.select();
                  if (onOpenSearch != null) {
                    onOpenSearch!();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recherche indisponible ici'),
                      ),
                    );
                  }
                },
              ),
            );
          }

          if (showNavProductsButton) {
            buttons.add(
              _btn(
                context,
                label: 'Produits',
                hint: 'Voir la liste des produits',
                icon: Icons.inventory_2_rounded,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenProducts ??
                    () {
                      HapticsUtil.select();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProductListPage(),
                        ),
                      );
                    },
              ),
            );
          }
          if (showNavCustomersButton) {
            buttons.add(
              _btn(
                context,
                label: 'Clients',
                hint: 'Voir la liste des clients',
                icon: Icons.group_rounded,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenCustomers ??
                    () {
                      HapticsUtil.select();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustomerListPage(),
                        ),
                      );
                    },
              ),
            );
          }
          if (showNavCategoriesButton) {
            buttons.add(
              _btn(
                context,
                label: 'Catégories',
                hint: 'Voir la liste des catégories',
                icon: Icons.category_outlined,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenCategories ??
                    () {
                      HapticsUtil.select();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryListPage(),
                        ),
                      );
                    },
              ),
            );
          }
          if (showNavAccountsButton) {
            buttons.add(
              _btn(
                context,
                label: 'Comptes',
                hint: 'Voir la liste des comptes',
                icon: Icons.account_balance_wallet_outlined,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenAccounts ??
                    () {
                      HapticsUtil.select();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountListPage(),
                        ),
                      );
                    },
              ),
            );
          }
        }

        if (showNavCustomersButton) {
          buttons.add(
            _btn(
              context,
              label: 'Entreprise',
              hint: 'Voir vos entreprises',
              icon: Icons.home_rounded,
              tone: Theme.of(context).colorScheme.primary,
              onTap:
                  onOpenChatbot ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CompanyListPage(),
                      ),
                    );
                  },
            ),
          );
        }

        if (showNavReportButton) {
          buttons.add(
            _btn(
              context,
              label: 'Rapport',
              hint: 'Ouvrir les rapports',
              icon: Icons.assessment_rounded,
              tone: Theme.of(context).colorScheme.primary,
              onTap:
                  onOpenReport ??
                  () {
                    HapticsUtil.select();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReportPage()),
                    );
                  },
            ),
          );
        }

        if (showNavMarketplaceButton) {
          buttons.add(
            _btn(
              context,
              label: 'Marketplace',
              hint: 'Ouvrir la marketplace',
              icon: Icons.store_rounded,
              tone: Theme.of(context).colorScheme.primary,
              onTap:
                  onOpenMarketplace ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MarketplacePage(),
                      ),
                    );
                  },
            ),
          );
        }

        if (showNavChatbotButton) {
          buttons.add(
            _btn(
              context,
              label: 'Assistant IA',
              hint: 'Discuter avec l’assistant',
              icon: Icons.chat_bubble_rounded,
              tone: Theme.of(context).colorScheme.primary,
              onTap:
                  onOpenChatbot ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatbotPage()),
                    );
                  },
            ),
          );
        }

        if (buttons.isEmpty) return const SizedBox.shrink();

        final w = c.maxWidth;
        final spacing = w < 360 ? 8.0 : 12.0;
        final cols = _columnsForWidth(w, buttons.length);
        final calcWidth = (w - (spacing * (cols - 1))) / cols;
        final itemWidth = calcWidth.clamp(64.0, 360.0);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: buttons
              .map((b) => SizedBox(width: itemWidth as double, child: b))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _btn(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    required Color tone,
    required VoidCallback? onTap,
  }) {
    return _TonedFilledButton(
      label: label,
      semanticHint: hint,
      icon: icon,
      tone: tone,
      onPressed: onTap,
    );
  }

  static int _columnsForWidth(double w, int count) {
    if (w >= 1040) return 5;
    if (w >= 840) return 4;
    if (w >= 600) return 3;
    if (w >= 360) return 3;
    return count >= 3 ? 3 : count;
  }
}

class _TonedFilledButton extends StatefulWidget {
  final String label;
  final String semanticHint;
  final IconData icon;
  final Color tone;
  final VoidCallback? onPressed;

  const _TonedFilledButton({
    required this.label,
    required this.semanticHint,
    required this.icon,
    required this.tone,
    required this.onPressed,
  });

  @override
  State<_TonedFilledButton> createState() => _TonedFilledButtonState();
}

class _TonedFilledButtonState extends State<_TonedFilledButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _activate() async {
    if (widget.onPressed == null) return;
    await HapticsUtil.vibrate();
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = widget.tone;
    final hsl = HSLColor.fromColor(base);
    final light = hsl
        .withLightness((hsl.lightness + (isDark ? 0.10 : 0.20)).clamp(0, 1))
        .toColor();
    final dark = hsl
        .withLightness((hsl.lightness - (isDark ? 0.10 : 0.05)).clamp(0, 1))
        .toColor();
    final bgA = isDark ? light.withOpacity(0.22) : light.withOpacity(0.18);
    final bgB = isDark ? dark.withOpacity(0.28) : dark.withOpacity(0.16);
    final fg = isDark ? base.withOpacity(0.98) : base.withOpacity(0.92);
    final radius = BorderRadius.circular(16);
    final hoveredOrFocused = _hovered || _focused;

    final boxShadow = hoveredOrFocused
        ? [
            BoxShadow(
              color: base.withOpacity(isDark ? 0.26 : 0.20),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ]
        : const <BoxShadow>[];

    final border = Border.all(
      color: hoveredOrFocused ? fg.withOpacity(0.45) : Colors.transparent,
      width: hoveredOrFocused ? 1.2 : 0,
    );

    return FocusableActionDetector(
      mouseCursor: widget.onPressed == null
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      child: Semantics(
        button: true,
        enabled: widget.onPressed != null,
        label: widget.label,
        onTapHint: widget.semanticHint,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter): _activate,
            const SingleActivator(LogicalKeyboardKey.space): _activate,
            const SingleActivator(LogicalKeyboardKey.select): _activate,
          },
          child: Tooltip(
            message: widget.semanticHint,
            waitDuration: const Duration(milliseconds: 500),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: _pressed ? 0.98 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgA, bgB],
                  ),
                  borderRadius: radius,
                  border: border,
                  boxShadow: boxShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: radius,
                    splashColor: fg.withOpacity(0.10),
                    highlightColor: fg.withOpacity(0.06),
                    onHighlightChanged: (v) => setState(() => _pressed = v),
                    onTapDown: (_) => HapticsUtil.tapLight(),
                    onLongPress: () => HapticsUtil.tapMedium(),
                    onTap: widget.onPressed == null ? null : _activate,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cw = constraints.maxWidth;
                        final veryTight = cw < 96;
                        final tight = cw < 150;
                        final iconSize = veryTight
                            ? 28.0
                            : (tight ? 36.0 : (cw < 200 ? 44.0 : 56.0));
                        final fontSize = veryTight
                            ? 11.0
                            : (tight ? 12.0 : 14.0);
                        final padV = veryTight ? 10.0 : (tight ? 12.0 : 16.0);
                        final minH = veryTight ? 74.0 : (tight ? 88.0 : 118.0);

                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: minH,
                            minWidth: 64,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: padV,
                              horizontal: 12,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(widget.icon, size: iconSize, color: fg),
                                const SizedBox(height: 6),
                                Text(
                                  widget.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: fontSize,
                                    color: fg,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
