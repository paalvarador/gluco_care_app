enum PlanType { free, basic, ideal, premium }

class SubscriptionPlan {
  final PlanType type;
  final String name;
  final double price;
  final int maxCaregivers;
  final int? dataHistoryDays;
  final bool canExportPDF;

  SubscriptionPlan({
    required this.type,
    required this.name,
    required this.price,
    required this.maxCaregivers,
    this.dataHistoryDays,
    required this.canExportPDF,
  });

  static Map<PlanType, SubscriptionPlan> plans = {
    PlanType.free: SubscriptionPlan(
      type: PlanType.free,
      name: 'Plan Gratuito',
      price: 0.0,
      maxCaregivers: 1,
      dataHistoryDays: 3,
      canExportPDF: false,
    ),
    PlanType.basic: SubscriptionPlan(
      type: PlanType.basic,
      name: "Plan Básico",
      price: 4.99,
      maxCaregivers: 2,
      canExportPDF: true,
    ),
    PlanType.ideal: SubscriptionPlan(
      type: PlanType.ideal,
      name: "Plan Ideal",
      price: 9.99,
      maxCaregivers: 3,
      canExportPDF: true,
    ),
    PlanType.premium: SubscriptionPlan(
      type: PlanType.premium,
      name: "Plan Premium",
      price: 14.99,
      maxCaregivers: 100,
      canExportPDF: true
    )
  };
}