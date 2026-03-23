class PlanConfig {
  final String status;
  final int maxCaregivers;
  final int historyDays;
  final bool hasPdf;

  PlanConfig({
    required this.status,
    required this.maxCaregivers,
    required this.historyDays,
    required this.hasPdf
  });

  static PlanConfig getSettings(String status){
    switch(status){
      case 'basic':
        return PlanConfig(status: 'basic', maxCaregivers: 2, historyDays: 9999, hasPdf: true);
      case 'ideal':
        return PlanConfig(status: 'ideal', maxCaregivers: 3, historyDays: 9999, hasPdf: true);
      case 'premium':
        return PlanConfig(status: 'premium', maxCaregivers: 99, historyDays: 9999, hasPdf: true);
      case 'free':
      default:
        return PlanConfig(status: 'free', maxCaregivers: 1, historyDays: 3, hasPdf: false);
    }
  }
}