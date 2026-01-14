import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(
            title: '1) First Login & Onboarding',
            bullets: [
              'Create an account, then sign in.',
              'Take the short tour to learn the basics.',
              'Dashboard shows total balance, accounts, recent transactions and events.',
            ],
          ),
          _Section(
            title: '2) Accounts',
            bullets: [
              'Add checking/savings/credit accounts with a starting balance.',
              'Edit balances anytime.',
              'Pro allows unlimited accounts.',
            ],
          ),
          _Section(
            title: '3) Transactions',
            bullets: [
              'Add Income/Expense with amount, date, account and category.',
              'Link to projects to track budgets.',
              'Use filters to analyze trends.',
            ],
          ),
          _Section(
            title: '4) Recurring Payments',
            bullets: [
              'Add payments with frequency and next date.',
              'Use Process Overdue to catch up missed charges.',
            ],
          ),
          _Section(
            title: '5) Projects & Budgets',
            bullets: [
              'Create projects with budget and timeframe.',
              'Track Spent vs Budget automatically via linked transactions.',
            ],
          ),
          _Section(
            title: '6) Analytics',
            bullets: [
              'See total balance over time and per-account trends.',
              'Review expenses by category and income by account.',
            ],
          ),
          _Section(
            title: 'Tips & Support',
            bullets: [
              'Reconcile accounts by matching real statements.',
              'Group spend by initiative using Projects.',
              'Questions? Contact support at sheremelias@gmail.com.',
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.bullets});
  final String title;
  final List<String> bullets;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(b)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
