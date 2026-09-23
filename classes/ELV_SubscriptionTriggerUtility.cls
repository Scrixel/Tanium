/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Utility for the Ruby (Nue) Subscription trigger. Populates Supported Asset
 *            (ELV_Supported_Asset__c) on a support Subscription from the support quote line's
 *            direct Supported Hardware Line Asset, or by resolving the hardware Asset generated
 *            from the Supported Hardware Line referenced on the support quote line.
 */
public with sharing class ELV_SubscriptionTriggerUtility {
	private static final String ACTIVE_STATUS = 'Active';

	public static void populateSupportedAsset(List<Ruby__Subscription__c> subs) {
		System.debug(
			LoggingLevel.INFO,
			'ELV_SubscriptionTriggerUtility.populateSupportedAsset after insert started. Subscription count=' +
				subs.size()
		);
		enqueueSupportedAssetPopulation(getActiveSubscriptionIds(subs));
	}

	public static void populateSupportedAsset(
		List<Ruby__Subscription__c> subs,
		Map<Id, Ruby__Subscription__c> oldMap
	) {
		Set<Id> subIds = new Set<Id>();
		for (Ruby__Subscription__c sub : subs) {
			Ruby__Subscription__c oldSub = oldMap.get(sub.Id);
			if (!isActive(sub)) {
				System.debug(
					LoggingLevel.INFO,
					'ELV_SubscriptionTriggerUtility.populateSupportedAsset skipped subscription because it is not Active. ' +
						'Subscription Id=' +
						sub.Id +
						', subscription name=' +
						sub.Name +
						', status=' +
						sub.Ruby__Status__c +
						', order product=' +
						sub.Ruby__OrderProduct__c
				);
				continue;
			}


			Boolean orderProductChanged = oldSub == null ||
				sub.Ruby__OrderProduct__c != oldSub.Ruby__OrderProduct__c;
			Boolean becameActive = oldSub == null ||
				sub.Ruby__Status__c != oldSub.Ruby__Status__c;
			if (orderProductChanged) {
				System.debug(
					LoggingLevel.INFO,
					'ELV_SubscriptionTriggerUtility.populateSupportedAsset queued Active subscription. ' +
						'Subscription Id=' +
						sub.Id +
						', subscription name=' +
						sub.Name +
						', old status=' +
						oldSub?.Ruby__Status__c +
						', new status=' +
						sub.Ruby__Status__c +
						', old order product=' +
						oldSub?.Ruby__OrderProduct__c +
						', new order product=' +
						sub.Ruby__OrderProduct__c +
						', order product changed=' +
						orderProductChanged +
						', status changed=' +
						becameActive
				);
				subIds.add(sub.Id);
			} else {
				System.debug(
					LoggingLevel.INFO,
					'ELV_SubscriptionTriggerUtility.populateSupportedAsset skipped Active subscription because order product did not change. ' +
						'Subscription Id=' +
						sub.Id +
						', subscription name=' +
						sub.Name +
						', old status=' +
						oldSub?.Ruby__Status__c +
						', new status=' +
						sub.Ruby__Status__c +
						', old order product=' +
						oldSub?.Ruby__OrderProduct__c +
						', new order product=' +
						sub.Ruby__OrderProduct__c +
						', order product changed=' +
						orderProductChanged +
						', status changed=' +
						becameActive
				);
			}
		}
		enqueueSupportedAssetPopulation(subIds);
	}

	private static Set<Id> getActiveSubscriptionIds(List<Ruby__Subscription__c> subs) {
		Set<Id> subIds = new Set<Id>();
		for (Ruby__Subscription__c sub : subs) {
			if (sub.Id != null && isActive(sub)) {
				subIds.add(sub.Id);
			} else {
				System.debug(
					LoggingLevel.INFO,
					'ELV_SubscriptionTriggerUtility.getActiveSubscriptionIds skipped subscription because it is not Active. ' +
						'Subscription Id=' +
						sub.Id +
						', subscription name=' +
						sub.Name +
						', status=' +
						sub.Ruby__Status__c
				);
			}
		}
		return subIds;
	}

	private static Boolean isActive(Ruby__Subscription__c sub) {
		return sub.Ruby__Status__c == ACTIVE_STATUS;
	}

	private static void enqueueSupportedAssetPopulation(Set<Id> subIds) {
		if (subIds.isEmpty()) {
			System.debug(
				LoggingLevel.INFO,
				'ELV_SubscriptionTriggerUtility.enqueueSupportedAssetPopulation skipped. No subscriptions to process.'
			);
			return;
		}
		System.debug(
			LoggingLevel.INFO,
			'ELV_SubscriptionTriggerUtility.enqueueSupportedAssetPopulation enqueuing subscription Ids=' +
				subIds
		);
		System.enqueueJob(new PopulateSupportedAssetAsync(subIds));
	}

	public class PopulateSupportedAssetAsync implements Queueable {
		private Set<Id> subscriptionIds;

		public PopulateSupportedAssetAsync(Set<Id> subscriptionIds) {
			this.subscriptionIds = subscriptionIds;
		}

		public void execute(QueueableContext context) {
			System.debug(
				LoggingLevel.INFO,
				'ELV_SubscriptionTriggerUtility.PopulateSupportedAssetAsync started. Subscription Ids=' +
					subscriptionIds
			);
			Map<Id, Ruby__Subscription__c> subscriptionsById = getSubscriptionsById();
			for (Ruby__Subscription__c sub : subscriptionsById.values()) {
				System.debug(
					LoggingLevel.INFO,
					'ELV_SubscriptionTriggerUtility.PopulateSupportedAssetAsync re-queried subscription order product. ' +
						'Subscription Id=' +
						sub.Id +
						', subscription name=' +
						sub.Name +
						', status=' +
						sub.Ruby__Status__c +
						', Ruby__OrderProduct__c=' +
						sub.Ruby__OrderProduct__c +
						', OrderProduct QuoteLineItemId=' +
						sub.Ruby__OrderProduct__r?.QuoteLineItemId +
						', current supported asset=' +
						sub.ELV_Supported_Asset__c
				);
			}

			Set<Id> hardwareLineIds = getHardwareLineIds(subscriptionsById.values());
			Map<Id, Id> hardwareLineToAsset = hardwareLineIds.isEmpty()
				? new Map<Id, Id>()
				: getHardwareLineToAsset(hardwareLineIds);
			List<Ruby__Subscription__c> toUpdate = buildSupportedAssetUpdates(
				subscriptionsById,
				resolveSupportedAssets(subscriptionsById, hardwareLineToAsset)
			);

			if (!toUpdate.isEmpty()) {
				System.debug(
					LoggingLevel.INFO,
					'ELV_SubscriptionTriggerUtility.PopulateSupportedAssetAsync updating subscriptions=' +
						toUpdate
				);
				update toUpdate;
			} else {
				System.debug(
					LoggingLevel.INFO,
					'ELV_SubscriptionTriggerUtility.PopulateSupportedAssetAsync found no subscription updates.'
				);
			}
		}

		@TestVisible
		private Set<Id> getHardwareLineIds(List<Ruby__Subscription__c> subscriptions) {
			Set<Id> hardwareLineIds = new Set<Id>();
			for (Ruby__Subscription__c sub : subscriptions) {
				QuoteLineItem quoteLine = sub.Ruby__OrderProduct__r?.QuoteLineItem;
				System.debug(
					LoggingLevel.INFO,
					'ELV_SubscriptionTriggerUtility.getHardwareLineIds evaluating subscription. ' +
						'Subscription Id=' +
						sub.Id +
						', subscription name=' +
						sub.Name +
						', status=' +
						sub.Ruby__Status__c +
						', current supported asset=' +
						sub.ELV_Supported_Asset__c +
						', Ruby__OrderProduct__c=' +
						sub.Ruby__OrderProduct__c +
						', quote line Id=' +
						sub.Ruby__OrderProduct__r?.QuoteLineItemId +
						', supported hardware line=' +
						quoteLine?.ELV_Supported_Hardware_Line__c +
						', supported hardware line asset=' +
						quoteLine?.ELV_Supported_Hardware_Line_Asset__c
				);
				if (
					quoteLine?.ELV_Supported_Hardware_Line_Asset__c == null &&
					quoteLine?.ELV_Supported_Hardware_Line__c != null
				) {
					hardwareLineIds.add(quoteLine.ELV_Supported_Hardware_Line__c);
				}
			}
			return hardwareLineIds;
		}

		@TestVisible
		private Map<Id, Id> resolveSupportedAssets(
			Map<Id, Ruby__Subscription__c> subscriptionsById,
			Map<Id, Id> hardwareLineToAsset
		) {
			Map<Id, Id> subToDesiredAsset = new Map<Id, Id>();
			for (Ruby__Subscription__c sub : subscriptionsById.values()) {
				if (!isActive(sub)) {
					System.debug(
						LoggingLevel.INFO,
						'ELV_SubscriptionTriggerUtility.resolveSupportedAssets skipped subscription because it is not Active. ' +
							'Subscription Id=' +
							sub.Id +
							', subscription name=' +
							sub.Name +
							', status=' +
							sub.Ruby__Status__c
					);
					continue;
				}

				QuoteLineItem quoteLine = sub.Ruby__OrderProduct__r?.QuoteLineItem;
				if (quoteLine == null) {
					System.debug(
						LoggingLevel.INFO,
						'ELV_SubscriptionTriggerUtility.resolveSupportedAssets skipped subscription because no related quote line was found. ' +
							'Subscription Id=' +
							sub.Id +
							', subscription name=' +
							sub.Name +
							', Ruby__OrderProduct__c=' +
							sub.Ruby__OrderProduct__c
					);
					continue;
				}

				Id directAssetId = quoteLine?.ELV_Supported_Hardware_Line_Asset__c;
				if (directAssetId != null) {
					System.debug(
						LoggingLevel.INFO,
						'ELV_SubscriptionTriggerUtility.resolveSupportedAssets using direct supported hardware asset. ' +
							'Subscription Id=' +
							sub.Id +
							', subscription name=' +
							sub.Name +
							', Ruby__OrderProduct__c=' +
							sub.Ruby__OrderProduct__c +
							', quote line Id=' +
							sub.Ruby__OrderProduct__r?.QuoteLineItemId +
							', asset Id=' +
							directAssetId
					);
					subToDesiredAsset.put(sub.Id, directAssetId);
					continue;
				}

				Id hardwareLineId = quoteLine?.ELV_Supported_Hardware_Line__c;
				Id assetId = hardwareLineToAsset.get(hardwareLineId);
				if (assetId != null) {
					System.debug(
						LoggingLevel.INFO,
						'ELV_SubscriptionTriggerUtility.resolveSupportedAssets resolved asset from supported hardware line. ' +
							'Subscription Id=' +
							sub.Id +
							', subscription name=' +
							sub.Name +
							', Ruby__OrderProduct__c=' +
							sub.Ruby__OrderProduct__c +
							', quote line Id=' +
							sub.Ruby__OrderProduct__r?.QuoteLineItemId +
							', supported hardware line=' +
							hardwareLineId +
							', asset Id=' +
							assetId
					);
					subToDesiredAsset.put(sub.Id, assetId);
				} else if (hardwareLineId == null) {
					System.debug(
						LoggingLevel.INFO,
						'ELV_SubscriptionTriggerUtility.resolveSupportedAssets clearing supported asset because quote line has no supported hardware values. ' +
							'Subscription Id=' +
							sub.Id +
							', subscription name=' +
							sub.Name +
							', Ruby__OrderProduct__c=' +
							sub.Ruby__OrderProduct__c +
							', quote line Id=' +
							sub.Ruby__OrderProduct__r?.QuoteLineItemId
					);
					subToDesiredAsset.put(sub.Id, null);
				} else {
					System.debug(
						LoggingLevel.INFO,
						'ELV_SubscriptionTriggerUtility.resolveSupportedAssets found supported hardware line but no matching Asset. ' +
							'Subscription Id=' +
							sub.Id +
							', subscription name=' +
							sub.Name +
							', Ruby__OrderProduct__c=' +
							sub.Ruby__OrderProduct__c +
							', quote line Id=' +
							sub.Ruby__OrderProduct__r?.QuoteLineItemId +
							', supported hardware line=' +
							hardwareLineId
					);
				}
			}
			return subToDesiredAsset;
		}

		@TestVisible
		private List<Ruby__Subscription__c> buildSupportedAssetUpdates(
			Map<Id, Ruby__Subscription__c> subscriptionsById,
			Map<Id, Id> subToDesiredAsset
		) {
			List<Ruby__Subscription__c> toUpdate = new List<Ruby__Subscription__c>();
			for (Id subId : subToDesiredAsset.keySet()) {
				Id assetId = subToDesiredAsset.get(subId);
				if (subscriptionsById.get(subId).ELV_Supported_Asset__c != assetId) {
					System.debug(
						LoggingLevel.INFO,
						'ELV_SubscriptionTriggerUtility.buildSupportedAssetUpdates preparing update. ' +
							'Subscription Id=' +
							subId +
							', current asset=' +
							subscriptionsById.get(subId).ELV_Supported_Asset__c +
							', desired asset=' +
							assetId
					);
					toUpdate.add(new Ruby__Subscription__c(Id = subId, ELV_Supported_Asset__c = assetId));
				} else {
					System.debug(
						LoggingLevel.INFO,
						'ELV_SubscriptionTriggerUtility.buildSupportedAssetUpdates skipped subscription; supported asset already matches. ' +
							'Subscription Id=' +
							subId +
							', asset Id=' +
							assetId
					);
				}
			}
			return toUpdate;
		}

		private Map<Id, Ruby__Subscription__c> getSubscriptionsById() {
			return new Map<Id, Ruby__Subscription__c>([
				SELECT
					Id,
					Name,
					Ruby__Status__c,
					ELV_Supported_Asset__c,
					Ruby__OrderProduct__c,
					Ruby__OrderProduct__r.QuoteLineItemId,
					Ruby__OrderProduct__r.QuoteLineItem.ELV_Supported_Hardware_Line__c,
					Ruby__OrderProduct__r.QuoteLineItem.ELV_Supported_Hardware_Line_Asset__c
				FROM Ruby__Subscription__c
				WHERE Id IN :subscriptionIds
			]);
		}

		private Map<Id, Id> getHardwareLineToAsset(Set<Id> hardwareLineIds) {
			Map<Id, Id> hardwareLineToAsset = new Map<Id, Id>();
			for (Asset asset : [
				SELECT Id, Ruby__OrderProduct__r.QuoteLineItemId
				FROM Asset
				WHERE Ruby__OrderProduct__r.QuoteLineItemId IN :hardwareLineIds
			]) {
				System.debug(
					LoggingLevel.INFO,
					'ELV_SubscriptionTriggerUtility.getHardwareLineToAsset found Asset for quote line. ' +
						'QuoteLineItem Id=' +
						asset.Ruby__OrderProduct__r.QuoteLineItemId +
						', Asset Id=' +
						asset.Id
				);
				hardwareLineToAsset.put(asset.Ruby__OrderProduct__r.QuoteLineItemId, asset.Id);
			}
			return hardwareLineToAsset;
		}
	}
}