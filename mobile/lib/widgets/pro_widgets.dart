import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../ui/finsight_ui.dart';
import '../services/purchase_service.dart';
import '../utils/links.dart';

const String _kProTitle = 'FinSight Pro';
const String _kProLength = 'Monthly subscription';
const String _kProRenewal = 'Auto-renews monthly until canceled.';

String _proPrice() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return 'MX\$249/month on App Store';
  }
  return 'MX\$235/month on Google Play';
}

class ProBlock extends StatelessWidget {
  const ProBlock({super.key, required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FSCard(
                  variant: FSCardVariant.elevated,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FSSpacing.xl,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: FSColors.intentContainer(
                            context,
                            FSIntent.primary,
                          ),
                          borderRadius: BorderRadius.circular(FSRadius.lg),
                        ),
                        child: const Icon(
                          Icons.stars_rounded,
                          color: FSColors.primary,
                        ),
                      ),
                      const SizedBox(height: FSSpacing.lg),
                      Text(
                        '$feature is a Pro feature',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upgrade to unlock this feature and more.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const _ProSubscriptionDetails(centered: true),
                      const SizedBox(height: 16),
                      FSButton(
                        label: 'Upgrade to Pro',
                        icon: Icons.workspace_premium_outlined,
                        onPressed: () => PurchaseService().purchasePro(context),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Includes analytics, projects, invoices, the AI financial consultant, and unlimited accounts.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProMiniChip extends StatelessWidget {
  const ProMiniChip({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: const FSStatusBadge(
        label: 'PRO',
        variant: FSStatusBadgeVariant.info,
      ),
    );
  }
}

class UpgradeBanner extends StatelessWidget {
  const UpgradeBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return FSCard(
      variant: FSCardVariant.interactive,
      child: Padding(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final details = const Expanded(child: _ProBannerDetails());
            final button = FSButton(
              label: 'Upgrade',
              icon: Icons.workspace_premium_outlined,
              onPressed: () => PurchaseService().purchasePro(context),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.stars, color: FSColors.primary),
                      ),
                      const SizedBox(width: 12),
                      details,
                    ],
                  ),
                  const SizedBox(height: 12),
                  button,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.stars, color: FSColors.primary),
                      ),
                      const SizedBox(width: 12),
                      details,
                      const SizedBox(width: 12),
                      button,
                    ],
                  ),
                const SizedBox(height: 4),
                const _PurchaseLegalActions(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProSubscriptionDetails extends StatelessWidget {
  const _ProSubscriptionDetails({
    required this.centered,
    this.showLegalActions = true,
  });

  final bool centered;
  final bool showLegalActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          _kProTitle,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _kProLength,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _proPrice(),
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _kProRenewal,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodySmall,
        ),
        if (showLegalActions) ...[
          const SizedBox(height: 4),
          _PurchaseLegalActions(centered: centered),
        ],
      ],
    );
  }
}

class _ProBannerDetails extends StatelessWidget {
  const _ProBannerDetails();

  @override
  Widget build(BuildContext context) {
    return const _ProSubscriptionDetails(
      centered: false,
      showLegalActions: false,
    );
  }
}

class _PurchaseLegalActions extends StatelessWidget {
  const _PurchaseLegalActions({this.centered = false});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 0,
      children: [
        TextButton(
          onPressed: () => openLink(context, kPurchasePrivacyPolicyUrl),
          child: const Text('Privacy Policy'),
        ),
        if (isIos)
          TextButton(
            onPressed: () => openLink(context, kPurchaseTermsOfUseUrl),
            child: const Text('Terms of Use (EULA)'),
          ),
        if (isIos)
          TextButton(
            onPressed: () => PurchaseService().restorePurchases(context),
            child: const Text('Restore Purchases'),
          ),
      ],
    );
  }
}
