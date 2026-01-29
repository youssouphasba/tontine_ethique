import 'package:flutter_riverpod/flutter_riverpod.dart';

/// V14: Ad Campaign State Management
/// Manages merchant advertising campaigns with real state

enum CampaignStatus { pending, approved, rejected, active, paused }

class AdCampaignState {
  final String id;
  final String merchantId;
  final String merchantName;
  final String title;
  final String targetObjective;
  final double budget;
  final double spent;
  final int clicks;
  final int impressions;
  final CampaignStatus status;
  final DateTime createdAt;

  AdCampaignState({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.title,
    required this.targetObjective,
    required this.budget,
    this.spent = 0,
    this.clicks = 0,
    this.impressions = 0,
    this.status = CampaignStatus.pending,
    required this.createdAt,
  });

  AdCampaignState copyWith({
    double? spent,
    int? clicks,
    int? impressions,
    CampaignStatus? status,
  }) {
    return AdCampaignState(
      id: id,
      merchantId: merchantId,
      merchantName: merchantName,
      title: title,
      targetObjective: targetObjective,
      budget: budget,
      spent: spent ?? this.spent,
      clicks: clicks ?? this.clicks,
      impressions: impressions ?? this.impressions,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class MerchantState {
  final List<AdCampaignState> campaigns;
  final double totalBudget;
  final int totalClicks;
  final int totalImpressions;

  MerchantState({
    this.campaigns = const [],
    this.totalBudget = 0,
    this.totalClicks = 0,
    this.totalImpressions = 0,
  });

  MerchantState copyWith({
    List<AdCampaignState>? campaigns,
    double? totalBudget,
    int? totalClicks,
    int? totalImpressions,
  }) {
    return MerchantState(
      campaigns: campaigns ?? this.campaigns,
      totalBudget: totalBudget ?? this.totalBudget,
      totalClicks: totalClicks ?? this.totalClicks,
      totalImpressions: totalImpressions ?? this.totalImpressions,
    );
  }
}

class MerchantNotifier extends StateNotifier<MerchantState> {
  MerchantNotifier() : super(MerchantState());

  void createCampaign({
    required String merchantId,
    required String merchantName,
    required String title,
    required String targetObjective,
    required double budget,
  }) {
    final newCampaign = AdCampaignState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      merchantId: merchantId,
      merchantName: merchantName,
      title: title,
      targetObjective: targetObjective,
      budget: budget,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      campaigns: [...state.campaigns, newCampaign],
      totalBudget: state.totalBudget + budget,
    );
  }

  void approveCampaign(String campaignId) {
    final updated = state.campaigns.map((c) {
      if (c.id == campaignId) {
        return c.copyWith(status: CampaignStatus.active);
      }
      return c;
    }).toList();
    state = state.copyWith(campaigns: updated);
  }

  void rejectCampaign(String campaignId) {
    final updated = state.campaigns.map((c) {
      if (c.id == campaignId) {
        return c.copyWith(status: CampaignStatus.rejected);
      }
      return c;
    }).toList();
    state = state.copyWith(campaigns: updated);
  }

  void recordClick(String campaignId) {
    final updated = state.campaigns.map((c) {
      if (c.id == campaignId) {
        return c.copyWith(clicks: c.clicks + 1);
      }
      return c;
    }).toList();
    state = state.copyWith(
      campaigns: updated,
      totalClicks: state.totalClicks + 1,
    );
  }

  void recordImpression(String campaignId) {
    final updated = state.campaigns.map((c) {
      if (c.id == campaignId) {
        return c.copyWith(impressions: c.impressions + 1);
      }
      return c;
    }).toList();
    state = state.copyWith(
      campaigns: updated,
      totalImpressions: state.totalImpressions + 1,
    );
  }

  List<AdCampaignState> getPendingCampaigns() {
    return state.campaigns.where((c) => c.status == CampaignStatus.pending).toList();
  }

  List<AdCampaignState> getActiveCampaigns() {
    return state.campaigns.where((c) => c.status == CampaignStatus.active).toList();
  }
}

final merchantProvider = StateNotifierProvider<MerchantNotifier, MerchantState>((ref) {
  return MerchantNotifier();
});
