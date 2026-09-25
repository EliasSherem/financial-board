import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/purchase_service.dart';
import '../services/analytics_service.dart';
import '../utils/links.dart';

class ProBlock extends StatelessWidget {
  const ProBlock({super.key, required this.feature});
  final String feature;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),child: Card(child: Padding(padding: const EdgeInsets.all(24),child: Column(mainAxisSize: MainAxisSize.min,children: [
    Text(billingText(context,'$feature requires Pro','$feature requiere Pro'),style: Theme.of(context).textTheme.headlineSmall,textAlign: TextAlign.center),
    const SizedBox(height: 16), const _StoreSubscriptionDetails(),
    const SizedBox(height: 12),const _UpgradeButton(),const _PurchaseLegalActions(),
  ]))))));
}
class ProMiniChip extends StatelessWidget {
  const ProMiniChip({super.key});
  @override
  Widget build(BuildContext context) => Semantics(label: billingText(context,'Pro feature','Función Pro'),child: Container(margin: const EdgeInsets.only(top: 2),padding: const EdgeInsets.symmetric(horizontal: 6,vertical: 2),decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer,borderRadius: BorderRadius.circular(6)),child: Text('PRO',style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer,fontSize: 9,fontWeight: FontWeight.w700))));
}
class UpgradeBanner extends StatelessWidget {
  const UpgradeBanner({super.key});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
    const _StoreSubscriptionDetails(),const SizedBox(height: 12),const _UpgradeButton(),const _PurchaseLegalActions(),
  ])));
}
class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton();
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: PurchaseService(),builder: (context,_) => FilledButton(onPressed: PurchaseService().busy ? null : () => PurchaseService().purchasePro(context),child: Text(billingText(context,'View subscription options','Ver opciones de suscripción'))));
}
class _StoreSubscriptionDetails extends StatefulWidget {
  const _StoreSubscriptionDetails();
  @override
  State<_StoreSubscriptionDetails> createState() => _StoreSubscriptionDetailsState();
}
class _StoreSubscriptionDetailsState extends State<_StoreSubscriptionDetails> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {if(mounted) {
      AnalyticsService.instance.event('paywall_viewed');
      PurchaseService().loadProducts(context);
    }});
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: PurchaseService(),builder: (context,_) {
    final store=PurchaseService();
    return Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
      Text('FinSight Pro',style: Theme.of(context).textTheme.titleLarge),const SizedBox(height: 8),
      if(store.loading) Semantics(liveRegion: true,child: Text(billingText(context,'Loading store prices…','Cargando precios de la tienda…')))
      else if(store.error!=null) ...[Text(store.error!),TextButton(onPressed:()=>store.loadProducts(context),child:Text(billingText(context,'Retry','Reintentar')))]
      else if(store.products.isNotEmpty) Text(store.offerDescription(store.products.first,Localizations.localeOf(context).languageCode=='es'),style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(billingText(context,'Prices and eligible offers come from your store. Review all options before confirming.','Los precios y las ofertas elegibles vienen de tu tienda. Revisa las opciones antes de confirmar.')),
    ]);
  });
}
class _PurchaseLegalActions extends StatelessWidget {
  const _PurchaseLegalActions();
  @override
  Widget build(BuildContext context) => Wrap(spacing: 4,children: [
    TextButton(onPressed:()=>openLink(context,kPurchasePrivacyPolicyUrl),child:Text(billingText(context,'Privacy Policy','Política de privacidad'))),
    if(!kIsWeb&&defaultTargetPlatform==TargetPlatform.iOS) TextButton(onPressed:()=>openLink(context,kPurchaseTermsOfUseUrl),child:Text(billingText(context,'Terms of Use (EULA)','Términos de uso (EULA)'))),
    TextButton(onPressed:()=>PurchaseService().restorePurchases(context),child:Text(billingText(context,'Restore purchases','Restaurar compras'))),
  ]);
}
