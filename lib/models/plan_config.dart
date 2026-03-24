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
    required this.name
  });

  static PlanConfig getSettings(String status){
    switch(status){
      case 'basic':
        return PlanConfig(status: 'basic', name: 'Básico', maxCaregivers: 2, historyDays: 30, hasPdf: true);
      case 'ideal':
        return PlanConfig(status: 'ideal', name: 'Ideal', maxCaregivers: 3, historyDays: 90, hasPdf: true);
      case 'premium':
        return PlanConfig(status: 'premium', name: 'Premium', maxCaregivers: 99, historyDays: 9999, hasPdf: true);
      case 'free':
      default:
        return PlanConfig(status: 'free', name: 'Gratuito', maxCaregivers: 1, historyDays: 3, hasPdf: false);
    }
  }
}