/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Controller on Server_Deployment__c object
 * @Date:     2024-05-01
 * @Author:   Tanium Dev Team
 * ReuqestId  ModifiedDate  Description
 * SS-8070    2024-05-01    Created the class
 * SS-9072    2024-09-11    Added method containsCore (check for Core Module)
 * SS-9497    2024-10-16    Updated methods publishLicensingEvent, containsCore
 * SS-9738    2024-11-20    Updated method publishLicensingEvent
 * SS-9894    2024-12-17    Updated method publishLicensingEvent
 * SS-10095   2025-01-28    Updated method publishLicensingEvent, added method isCloud
 * SS-10144   2025-01-31    Updated method containsCore
 * SS-13269   2026-05-20    Comment and uncomment Hostnames and VanityURL fields for changing field types
 * SS-13337   2026-06-04	Added method getCompany and call to getCompany
 * SS-13457   2026-06-16	Updated method getCompany and call to method getCompany
 * SS-13718   2026-07-29    Updated method publishLicensingEvent
 * SS-13814   2026-08-09    Updated method publishLicensingEvent - eval field, added method isPocEval
 */
public without sharing class ServerDeploymentController {
	private static final String CORE_MODULE = 'Core';
	private static final String TANIUM_CLOUD_URL = '.cloud.tanium.com';
	private static final String TANIUM_FEDCLOUD_URL = '.cloud.taniumfed.com';
	private static final String SERVER_DEPLOYMENT_PREFIX = 'a04';
	private static final String POC_REQUEST_PREFIX = 'a7b';
	private static final Integer LICENSE_NOTES_MAX_SIZE = 2015;
	private static final String LICENSE_NOTES_DELIMITER = '---';

	@InvocableMethod(
		label='Generate Licensing Event'
		description='Generate Licensing Platform Event'
	)
	public static String[] generateLicensingEvent(POC_Request__c[] pocRequests) {
		return new List<String>{ generateLicensingEvent(pocRequests[0].Id) };
	}

	@AuraEnabled
	public static String generateLicensingEvent(Id recId) {
		POC_Request__c[] pocRequests = [
			SELECT
				Id,
				Server_Deployment__c,
				RecordTypeId,
				POC_Type__c,
				Account__r.Type,
				Account__r.Deployment_Method__c
			FROM POC_Request__c
			WHERE Id = :recId
		];

		if (pocRequests.isEmpty()) {
			return publishLicensingEvent(recId);
		}
		return publishPOCLicensingEvent(pocRequests[0].Server_Deployment__c, pocRequests[0]);
	}

	@AuraEnabled
	public static String publishLicensingEvent(Id serverDeploymentId) {
		EnhancedReturnType rt = noChildRecords(serverDeploymentId)
			? new EnhancedReturnType(
					false,
					'There are no Server Deployment Subscription records to publish'
			  )
			: !containsCore(null, serverDeploymentId)
					? new EnhancedReturnType(false, 'There has to be a core module')
					: publishLicensingEvent(serverDeploymentId, null);
		return JSON.serialize(rt);
	}

	@AuraEnabled
	public static String publishPOCLicensingEvent(Id serverDeploymentId, POC_Request__c pocRequest) {
		EnhancedReturnType rt = (serverDeploymentId == null)
			? new EnhancedReturnType(false, 'The Server Deployment field cannot be empty')
			: noChildRecords(pocRequest.Id)
					? new EnhancedReturnType(false, 'There are no POC Module records to publish')
					: !containsCore(pocRequest.Id, serverDeploymentId)
							? new EnhancedReturnType(false, 'There has to be a core module')
							: publishLicensingEvent(serverDeploymentId, pocRequest);
		return JSON.serialize(rt);
	}

	@TestVisible
	private static EnhancedReturnType publishLicensingEvent(
		Id serverDeploymentId,
		POC_Request__c pocRequest
	) {
		Id taasRecTypeId = Utility.getRecordTypeIdByAPIName('Server_Deployment__c', 'TaaS');
		EnhancedReturnType rt = new EnhancedReturnType(true, 'Success');
		String entitlementType = null;
		Id pocRequestId = pocRequest == null ? null : pocRequest.Id;
		Server_Deployment__c serverDeployment = [
			SELECT
				Id, // Deployment ID
				Account__r.Name, // Name__c
				Account__r.Id,
				Account__r.Domain__c,
				Account__r.Deployment_Method__c,
				Account__r.Monthly_FOC_AI_Credits__c,
				Account__r.Type,
				RecordTypeId,
				Account__r.Healthcheck_Available_Picklist__c,
				Server_Device_Type__c, // Infrastructure
				Tanium_Cloud_Admin__r.Email,
				License_delivery_email_primary__c,
				Cloud_Region__c, // Cloud Region
				Server_Hostnames__c, // Hostnames
				Vanity_URL__c,
				Type__c, // Environment
				Compliance_Framework__c,
				Sales_Order__c,
				Is_Titankube_Integration_Required__c, // Titankube
				License_Notes__c, // Notes
				Country__r.Name,
				Cloud_Provider__c
			FROM Server_Deployment__c
			WHERE Id = :serverDeploymentId
		];

		Boolean onPrem = pocRequestId == null
			? isOnPrem(serverDeployment.RecordTypeId)
			: isOnPrem(pocRequest.RecordTypeId);
		Boolean isTrial = isTrial(pocRequest);
		String licenseNotes = getLicenseNotes(serverDeployment);
		String taniumURL = (serverDeployment.Compliance_Framework__c == 'tc_usg')
			? TANIUM_FEDCLOUD_URL
			: TANIUM_CLOUD_URL;
		entitlementType = (pocRequestId == null) ? 'GA' : isPocEval(pocRequest) ? 'Evaluation' : 'GA';
		Licensing_Event__e licensingEvent = new Licensing_Event__e();
		licensingEvent.Company__c = pocRequestId != null ? 'Tanium' : getCompany(serverDeployment.Id);
		licensingEvent.Version__c = '';
		licensingEvent.Environment__c = serverDeployment.Type__c;
		licensingEvent.Name__c = serverDeployment.Account__r.Name;
		licensingEvent.Account_ID__c = serverDeployment.Account__r.Id;
		licensingEvent.Account_Type__c = serverDeployment.Account__r.Type != 'Prospect'
			? 'Customer'
			: serverDeployment.Account__r.Type;
		licensingEvent.AI_Free_Credits__c = serverDeployment.Server_Device_Type__c == 'On-Prem'
			? 0
			: serverDeployment.Account__r.Monthly_FOC_AI_Credits__c ?? 10000;
		licensingEvent.Data_Sharing__c = (serverDeployment.RecordTypeId == taasRecTypeId)
			? true
			: (serverDeployment.Account__r.Healthcheck_Available_Picklist__c == 'Yes') ? true : false;
		licensingEvent.Domain__c = serverDeployment.Account__r.Domain__c;
		licensingEvent.Deployment_ID__c = serverDeployment.Id;
		licensingEvent.Fed_Ramp__c = false;
		licensingEvent.OnPrem__c = onPrem;
		licensingEvent.Notes__c = licenseNotes;
		licensingEvent.Infrastructure__c = serverDeployment.Server_Device_Type__c;
		licensingEvent.Cloud_Region__c = serverDeployment.Cloud_Region__c;
		licensingEvent.Country__c = serverDeployment.Country__r.Name;
		licensingEvent.VanityURL__c = serverDeployment.Vanity_URL__c + taniumURL;
		licensingEvent.Taas_Admin_Email__c = onPrem
			? serverDeployment.License_delivery_email_primary__c
			: serverDeployment.Tanium_Cloud_Admin__r.Email;
		licensingEvent.Hostnames__c = serverDeployment.Server_Hostnames__c;
		licensingEvent.Compliance_Framework__c = serverDeployment.Compliance_Framework__c;
		licensingEvent.Cloud_Provider__c = serverDeployment.Cloud_Provider__c == null
			? ''
			: serverDeployment.Cloud_Provider__c;
		licensingEvent.Entitlement_Type__c = entitlementType;
		licensingEvent.SalesOrder__c = serverDeployment.Sales_Order__c;
		licensingEvent.Titankube__c = (serverDeployment.Is_Titankube_Integration_Required__c == 'Yes')
			? true
			: false;
		licensingEvent.Created_By__c = UserInfo.getName();
		licensingEvent.POC_Request__c = pocRequestId;
		licensingEvent.IsPoc__c = (pocRequestId == null) ? false : true;

		Database.SaveResult result = EventBus.publish(licensingEvent);
		if (!result.isSuccess()) {
			rt.retResult = false;
			rt.retData = result.getErrors()[0].getMessage();
		}
		if (!rt.retResult == false) {
			updateLicensingFields(serverDeploymentId, pocRequestId);
		}
		return rt;
	}

	@TestVisible
	private static String getLicenseNotes(Server_Deployment__c serverDeployment) {
		String licenseNotes = '';
		licenseNotes += serverDeployment.Sales_Order__c == null
			? ''
			: serverDeployment.Sales_Order__c;
		licenseNotes += LICENSE_NOTES_DELIMITER;
		licenseNotes += serverDeployment.License_Notes__c == null
			? ''
			: serverDeployment.License_Notes__c;
		return licenseNotes.length() > LICENSE_NOTES_MAX_SIZE
			? licenseNotes.substring(0, LICENSE_NOTES_MAX_SIZE)
			: licenseNotes;
	}

	@TestVisible
	private static Boolean noChildRecords(Id recId) {
		Integer numRecords = 0;

		if (String.valueOf(recId).left(3) == SERVER_DEPLOYMENT_PREFIX) {
			numRecords = [
				SELECT COUNT()
				FROM Server_Deployment_Subscriptions__c
				WHERE Server_Deployment__c = :recId
			];
		}
		if (String.valueOf(recId).left(3) == POC_REQUEST_PREFIX) {
			numRecords = [SELECT COUNT() FROM POC_Module__c WHERE POC_Request__c = :recId];
		}
		return (numRecords == 0);
	}

	@TestVisible
	private static Boolean isOnPrem(Id recordTypeId) {
		Set<Id> onPremIds = new Set<Id>();
		onPremIds.add(Utility.getRecordTypeIdByAPIName('Server_Deployment__c', 'OnPrem'));
		onPremIds.add(Utility.getRecordTypeIdByAPIName('POC_Request__c', 'Standard'));
		onPremIds.add(Utility.getRecordTypeIdByAPIName('POC_Request__c', 'Partner_On_Prem'));
		return onPremIds.contains(recordTypeId);
	}

	@TestVisible
	private static Boolean isTrial(POC_Request__c pocRequest) {
		Id trialRecTypeId = Utility.getRecordTypeIdByAPIName('POC_Request__c', 'HFPOC');
		return pocRequest == null ? false : pocRequest.RecordTypeId == trialRecTypeId ? true : false;
	}

	@TestVisible
	private static Boolean isPocEval(POC_Request__c pocRequest) {
		Boolean isEvalEntitlementType = true;
		Id taasRecordTypeId = Utility.getRecordTypeIdByAPIName('POC_Request__c', 'TaaS');
		Set<String> evalDeploymentMethods = new Set<String>{
			'Cloud',
			'Hybrid',
			'Tanium Cloud for US Government'
		};

		if (
			pocRequest.RecordTypeId == taasRecordTypeId &&
			(pocRequest.Account__r.Deployment_Method__c != null &&
			evalDeploymentMethods.contains(pocRequest.Account__r.Deployment_Method__c)) &&
			pocRequest.Account__r.Type != 'Prospect'
		) {
			isEvalEntitlementType = false;
		}
		return isEvalEntitlementType;
	}

	@TestVisible
	private static Boolean containsCore(Id pocRequestId, Id serverDeploymentId) {
		Set<Id> productIds = new Set<Id>();
		Set<Id> optionProductIds = new Set<Id>();
		Set<Id> allProductIds;
		Boolean containsCore = false;

		Server_Deployment_Subscriptions__c[] serverDeploymentSubscriptions = [
			SELECT Id, Subscription__r.SBQQ__Product__r.Id
			FROM Server_Deployment_Subscriptions__c
			WHERE Server_Deployment__c = :serverDeploymentId
		];
		for (
			Server_Deployment_Subscriptions__c serverDeploymentSubscription : serverDeploymentSubscriptions
		) {
			productIds.add(serverDeploymentSubscription.Subscription__r.SBQQ__Product__r.Id);
		}

		for (SBQQ__ProductOption__c productOption : [
			SELECT Id, SBQQ__OptionalSKU__c
			FROM SBQQ__ProductOption__c
			WHERE SBQQ__ConfiguredSKU__c IN :productIds
		]) {
			optionProductIds.add(productOption.SBQQ__OptionalSKU__c);
		}
		allProductIds = new Set<Id>(productIds);
		allProductIds.addAll(optionProductIds);
		for (Product_Module__c productModule : [
			SELECT Id, Module__r.Name
			FROM Product_Module__c
			WHERE Product__c IN :allProductIds
		]) {
			if (productModule.Module__r.Name == CORE_MODULE) {
				containsCore = true;
			}
		}
		if (pocRequestId != null && containsCore == false) {
			for (POC_Module__c pocModule : [
				SELECT Id, Module__r.Name
				FROM POC_Module__c
				WHERE POC_Request__c = :pocRequestId
			]) {
				if (pocModule.Module__r.Name == CORE_MODULE) {
					containsCore = true;
				}
			}
		}
		return containsCore;
	}

	@TestVisible
	private static String getCompany(Id serverDeploymentId) {
		String company = 'Tanium';
		Set<String> productCodes = new Set<String>();

		for (Server_Deployment_Subscriptions__c serverDeploymentSubscription : [
			SELECT Id, Product_Code__c
			FROM Server_Deployment_Subscriptions__c
			WHERE Server_Deployment__c = :serverDeploymentId AND Subscription__c != NULL
		]) {
			productCodes.add(serverDeploymentSubscription.Product_Code__c);
		}

		for (String productCode : productCodes) {
			if (productCode != null && productCode.contains('NOW')) {
				company = 'ServiceNow';
				break;
			}
			if (productCode != null && productCode.contains('SFDC')) {
				company = 'Salesforce';
				break;
			}
		}
		return company;
	}

	private static void updateLicensingFields(Id serverDeploymentId, Id pocRequestId) {
		Server_Deployment__c serverDeployment = null;
		POC_Request__c pocRequest = null;

		if (pocRequestId == null) {
			serverDeployment = new Server_Deployment__c(Id = serverDeploymentId);
			serverDeployment.License_Generated_By__c = UserInfo.getUserId();
			serverDeployment.License_Generated_DateTime__c = System.now();
		} else {
			pocRequest = new POC_Request__c(Id = pocRequestId);
			pocRequest.License_Generated_By__c = UserInfo.getUserId();
			pocRequest.License_Generated_DateTime__c = System.now();
		}
		try {
			if (pocRequest == null) {
				update serverDeployment;
			} else {
				update pocRequest;
			}
		} catch (Exception e) {
			Logger.error('ServerDeploymentController.updateLicensingFields', e);
			Logger.saveLog();
		}
	}
}