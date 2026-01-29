enum AdStatus { pending, approved, rejected }

class AdCampaign {
  final String id;
  final String merchantId;
  final String title;
  final String imageUrl;
  final String targetObjective; // e.g. "Moto", "Voyage"
  final double budget;
  final int views;
  final int clicks;
  final AdStatus status; // Replaces isActive

  AdCampaign({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.imageUrl,
    required this.targetObjective,
    required this.budget,
    this.views = 0,
    this.clicks = 0,
    this.status = AdStatus.pending, // Default to pending
  });
}
