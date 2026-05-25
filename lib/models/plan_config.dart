class PlanConfig {
  final String status;
  final int maxCaregivers;
  final int historyDays;
  final bool hasPdf;
  final String name;

  PlanConfig({
    required this.status,
    required this.maxCaregivers,
    required this.historyDays,
    required this.hasPdf,
    required this.name,
  });

  static PlanConfig getSettings(String status) {
    switch (status) {
      case 'pro':
      case 'premium': // backward-compat: existing glucocare_premium_monthly subscriber
      case 'ideal':   // backward-compat: legacy status
      case 'basic':   // backward-compat: legacy basic subscribers get Pro features
        return PlanConfig(
          status: 'pro',
          name: 'Pro',
          maxCaregivers: 5,
          historyDays: 9999,
          hasPdf: true,
        );
      case 'free':
      default:
        return PlanConfig(
          status: 'free',
          name: 'Gratuito',
          maxCaregivers: 1,
          historyDays: 7,
          hasPdf: false,
        );
    }
  }
}
