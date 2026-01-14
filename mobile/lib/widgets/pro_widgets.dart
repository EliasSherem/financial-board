import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/purchase_service.dart';
import '../utils/links.dart';

class ProBlock extends StatelessWidget {
  const ProBlock({super.key, required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$feature is a Pro feature',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Upgrade to unlock this feature and more. \$235 MXN /month', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => PurchaseService().purchasePro(context),
                child: const Text('Upgrade to Pro'),
              ),
              const SizedBox(height: 8),
              const Text('Includes analytics, projects, invoices, and unlimited accounts.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class ProMiniChip extends StatelessWidget {
  const ProMiniChip({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFE6F0FF), borderRadius: BorderRadius.circular(6)),
      child: const Text('PRO', style: TextStyle(color: Color(0xFF2563EB), fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class UpgradeBanner extends StatelessWidget {
  const UpgradeBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.stars, color: Color(0xFF2563EB)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Upgrade to Pro', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Unlock analytics, projects & invoices — \$235 MXN/mo'),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => PurchaseService().purchasePro(context),
              child: const Text('Upgrade'),
            )
          ],
        ),
      ),
    );
  }
}

