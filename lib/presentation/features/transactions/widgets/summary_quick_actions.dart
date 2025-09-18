// Responsive quick actions grid including expense/income and debt/repayment/loan creation, plus nav shortcuts.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/marketplace/presentation/marketplace_page.dart';

import 'package:money_pulse/presentation/features/transactions/pages/transaction_list_page.dart';
import 'package:money_pulse/presentation/features/pos/pos_page.dart';
import 'package:money_pulse/presentation/features/settings/settings_page.dart';
import 'package:money_pulse/presentation/features/reports/report_page.dart';
import 'package:money_pulse/presentation/features/products/product_list_page.dart';
import 'package:money_pulse/presentation/features/customers/customer_list_page.dart';
import 'package:money_pulse/presentation/features/categories/category_list_page.dart';
import 'package:money_pulse/presentation/features/accounts/account_page.dart';
import 'package:money_pulse/presentation/features/stock/stock_level_list_page.dart';

import '../../ia/chatbot_page.dart';
import '../../ia/chatbot_provider.dart';

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
              icon: Icons.account_balance_rounded,
              tone: Theme.of(context).colorScheme.secondary,
              onTap: onAddLoan,
            ),
          );
        }

        if (showNavShortcuts) {
          if (showNavTransactionsButton) {
            buttons.add(
              _btn(
                context,
                label: 'Transactions',
                icon: Icons.list_alt,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenTransactions ??
                    () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TransactionListPage(),
                        ),
                      );
                    },
              ),
            );
          }
          if (showNavPosButton) {
            buttons.add(
              _btn(
                context,
                label: 'POS',
                icon: Icons.point_of_sale,
                tone: Theme.of(context).colorScheme.secondary,
                onTap:
                    onOpenPos ??
                    () {
                      HapticFeedback.selectionClick();
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
                icon: Icons.settings,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenSettings ??
                    () {
                      HapticFeedback.selectionClick();
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
                icon: Icons.search_rounded,
                tone: Theme.of(context).colorScheme.primary,
                onTap: () {
                  HapticFeedback.selectionClick();
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
          if (showNavStockButton) {
            buttons.add(
              _btn(
                context,
                label: 'Stock',
                icon: Icons.inventory_rounded,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenStock ??
                    () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StockLevelListPage(),
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
                icon: Icons.assessment_rounded,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenReport ??
                    () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ReportPage()),
                      );
                    },
              ),
            );
          }
          if (showNavProductsButton) {
            buttons.add(
              _btn(
                context,
                label: 'Produits',
                icon: Icons.inventory_2_rounded,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenProducts ??
                    () {
                      HapticFeedback.selectionClick();
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
                icon: Icons.group_rounded,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenCustomers ??
                    () {
                      HapticFeedback.selectionClick();
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
                icon: Icons.category_outlined,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenCategories ??
                    () {
                      HapticFeedback.selectionClick();
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
                icon: Icons.account_balance_wallet_outlined,
                tone: Theme.of(context).colorScheme.primary,
                onTap:
                    onOpenAccounts ??
                    () {
                      HapticFeedback.selectionClick();
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

        if (showNavMarketplaceButton) {
          buttons.add(
            _btn(
              context,
              label: 'Marketplace',
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
              label: 'Chatbot',
              icon: Icons.chat_bubble_rounded,
              tone: Theme.of(context).colorScheme.secondary,
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
    required IconData icon,
    required Color tone,
    required VoidCallback? onTap,
  }) {
    return _TonedFilledButton(
      label: label,
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
  final IconData icon;
  final Color tone;
  final VoidCallback? onPressed;

  const _TonedFilledButton({
    required this.label,
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
        label: widget.label,
        onTapHint: 'Ouvrir',
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
                onTap: widget.onPressed == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        widget.onPressed!.call();
                      },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cw = constraints.maxWidth;
                    final veryTight = cw < 96;
                    final tight = cw < 150;
                    final iconSize = veryTight
                        ? 28.0
                        : (tight ? 36.0 : (cw < 200 ? 44.0 : 56.0));
                    final fontSize = veryTight ? 11.0 : (tight ? 12.0 : 14.0);
                    final padV = veryTight ? 10.0 : (tight ? 12.0 : 16.0);
                    final minH = veryTight ? 74.0 : (tight ? 88.0 : 118.0);

                    return ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minH),
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
    );
  }
}
