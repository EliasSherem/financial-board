import 'package:flutter/material.dart';
import '../ui/finsight_ui.dart';
import '../utils/format.dart';
import '../i18n.dart';
import '../models.dart';

class AccountListSummary extends StatelessWidget {
  const AccountListSummary({super.key, required this.accounts, this.onAdd});
  final List<Account> accounts;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return FSCard(
      variant: FSCardVariant.elevated,
      padding: const EdgeInsets.all(FSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryHeader(
            title: I18n.t(context, 'analytics.accountSummary'),
            icon: Icons.account_balance_wallet_outlined,
            actions: [
              _SummaryIconButton(
                onPressed: onAdd,
                icon: Icons.add_rounded,
                tooltip: I18n.t(context, 'label.addAccount'),
              ),
              const SizedBox(width: FSSpacing.xs),
              _SummaryIconButton(
                onPressed: () {},
                icon: Icons.more_horiz_rounded,
              ),
            ],
          ),
          const SizedBox(height: FSSpacing.md),
          if (accounts.isEmpty)
            FSEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: I18n.t(context, 'analytics.accountSummary'),
              action:
                  onAdd == null
                      ? null
                      : FSButton(
                        label: I18n.t(context, 'label.addAccount'),
                        icon: Icons.add_rounded,
                        onPressed: onAdd,
                        variant: FSButtonVariant.outline,
                      ),
            )
          else
            ...accounts.map(
              (a) => _AccountSummaryRow(
                account: a,
                typeLabel:
                    a.isInvestment
                        ? I18n.t(context, 'accounts.type.investment')
                        : (a.type ?? ''),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.title,
    required this.icon,
    this.actions = const [],
  });

  final String title;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SectionIcon(icon: icon),
        const SizedBox(width: FSSpacing.md),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ...actions,
      ],
    );
  }
}

class _AccountSummaryRow extends StatelessWidget {
  const _AccountSummaryRow({required this.account, required this.typeLabel});

  final Account account;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    final balanceColor =
        account.displayBalance < 0
            ? FSColors.danger
            : Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(top: FSSpacing.sm),
      padding: const EdgeInsets.all(FSSpacing.md),
      decoration: BoxDecoration(
        color: FSColors.surface(context),
        borderRadius: BorderRadius.circular(FSRadius.lg),
        border: Border.all(color: FSColors.border(context)),
      ),
      child: Row(
        children: [
          _SectionIcon(
            icon:
                account.isInvestment
                    ? Icons.trending_up_rounded
                    : Icons.account_balance_rounded,
            subtle: true,
          ),
          const SizedBox(width: FSSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (typeLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FSColors.mutedText(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: FSSpacing.md),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                money(account.displayBalance),
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: balanceColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryIconButton extends StatelessWidget {
  const _SummaryIconButton({
    required this.onPressed,
    required this.icon,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(38),
        backgroundColor: FSColors.surface(context),
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(color: FSColors.border(context)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.md),
        ),
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon, this.subtle = false});

  final IconData icon;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: subtle ? 38 : 40,
      height: subtle ? 38 : 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            subtle
                ? FSColors.surfaceElevated(context)
                : FSColors.intentContainer(context, FSIntent.primary),
        borderRadius: BorderRadius.circular(FSRadius.md),
        border: Border.all(
          color:
              subtle
                  ? FSColors.border(context)
                  : FSColors.intentBorder(context, FSIntent.primary),
        ),
      ),
      child: Icon(
        icon,
        size: subtle ? 19 : 20,
        color: subtle ? FSColors.mutedText(context) : FSColors.primary,
      ),
    );
  }
}
