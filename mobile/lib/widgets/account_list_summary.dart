import 'package:flutter/material.dart';

import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';
import '../models.dart';
import '../utils/format.dart';

class AccountListSummary extends StatelessWidget {
  const AccountListSummary({super.key, required this.accounts, this.onAdd});

  final List<Account> accounts;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LGSolidCard(
      variant: LGCardVariant.elevated,
      padding: const EdgeInsets.all(LGSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  I18n.t(context, 'analytics.accountSummary'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                tooltip: I18n.t(context, 'label.addAccount'),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.sm),
          ...accounts.map(
            (account) => Padding(
              padding: const EdgeInsets.symmetric(vertical: LGSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(LGRadius.md),
                    ),
                    child: Icon(
                      account.isInvestment
                          ? Icons.trending_up_rounded
                          : Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: LGSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.isInvestment
                              ? I18n.t(context, 'accounts.type.investment')
                              : (account.type ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: LGColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LGSpacing.md),
                  Text(
                    money(account.displayBalance),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
