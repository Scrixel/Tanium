/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Controller on serverDeploymentPreviewLicenseEvent LWC
 * @Date:     2026-09-10
 * @Author:   Tanium Dev Team
 * ReuqestId  ModifiedDate  Description
 * SS-13774   2026-09-10    Initial development
 */
public without sharing class ServerDeploymentPreviewLicenseController {
	private static final String LICENSE_NOTES_DELIMITER = '---';
	private static final Integer SUCCESSFUL_RESPONSE_CODE = 201;
	private static final String LICENSE_ID_PLACEHOLDER = '[***licenseid***]';
	private static final Integer LICENSED_MODULES_MAX_SIZE = 32500;
	private static final Id taasRecTypeId = Utility.getRecordTypeIdByAPIName(
		'Server_Deployment__c',
		'TaaS'
	);
	private static final Id onPremRecTypeId = Utility.getRecordTypeIdByAPIName(
		'Server_Deployment__c',
		'OnPrem'
	);

	@AuraEnabled
	public static List<LicenseDetails> getLicenseDetails(Id serverDeploymentId) {
		List<LicenseDetails> licenseDetails = new List<LicenseDetails>();
		Set<String> moduleNames = new Set<String>();
		Map<String, Decimal> moduleNameToSeats = new Map<String, Decimal>();
		Map<String, Date> moduleNameToStartDate = new Map<String, Date>();
		Map<String, Date> moduleNameToEndDate = new Map<String, Date>();

		for (
			Server_Deployment_Subscriptions__c serverDeploymentSubscription : [
				SELECT
					Id,
					Module__c,
					Subscription_Quantity__c,
					Entitlement_Start_Date__c, // Jason TODO - Verify these dates fields whole method
					Entitlement_End_Date__c
				FROM Server_Deployment_Subscriptions__c
				WHERE
					Server_Deployment__c = :serverDeploymentId
					AND Module__c != NULL
					AND Entitlement_End_Date__c >= TODAY
			]
		) {
			if (!moduleNames.contains(serverDeploymentSubscription.Module__c)) {
				moduleNames.add(serverDeploymentSubscription.Module__c);
				moduleNameToSeats.put(
					serverDeploymentSubscription.Module__c,
					serverDeploymentSubscription.Subscription_Quantity__c
				);
				moduleNameToStartDate.put(
					serverDeploymentSubscription.Module__c,
					serverDeploymentSubscription.Entitlement_Start_Date__c
				);
				moduleNameToEndDate.put(
					serverDeploymentSubscription.Module__c,
					serverDeploymentSubscription.Entitlement_End_Date__c
				);
			} else {
				moduleNameToSeats.put(
					serverDeploymentSubscription.Module__c,
					moduleNameToSeats.get(serverDeploymentSubscription.Module__c) +
					serverDeploymentSubscription.Subscription_Quantity__c
				);
				if (
					moduleNameToStartDate.get(serverDeploymentSubscription.Module__c) >
					serverDeploymentSubscription.Entitlement_Start_Date__c
				) {
					moduleNameToStartDate.put(
						serverDeploymentSubscription.Module__c,
						serverDeploymentSubscription.Entitlement_Start_Date__c
					);
				}
				if (
					moduleNameToEndDate.get(serverDeploymentSubscription.Module__c) <
					serverDeploymentSubscription.Entitlement_End_Date__c
				) {
					moduleNameToEndDate.put(
						serverDeploymentSubscription.Module__c,
						serverDeploymentSubscription.Entitlement_End_Date__c
					);
				}
			}
		}

		for (String moduleName : moduleNames) {
			licenseDetails.add(
				new LicenseDetails(
					moduleName,
					moduleNameToSeats.get(moduleName),
					moduleNameToStartDate.get(moduleName),
					moduleNameToEndDate.get(moduleName)
				)
			);
		}
		return licenseDetails;
	}

	@AuraEnabled
	public static List<String> getProductCodes(Id serverDeploymentId) {
		Set<String> productCodes = new Set<String>();

		String productCode;
		for (
			Server_Deployment_Subscriptions__c serverDeploymentSubscription : [
				SELECT Id, ELV_Product_Name__c, ELV_Product_Code__c
				FROM Server_Deployment_Subscriptions__c
				WHERE
					Server_Deployment__c = :serverDeploymentId
					AND ELV_Product_Code__c != NULL
					AND Entitlement_End_Date__c >= TODAY // Jason TODO - Verify this date field
			]
		) {
			productCode =
				serverDeploymentSubscription.ELV_Product_Name__c +
				' : ' +
				serverDeploymentSubscription.ELV_Product_Code__c;
			productCodes.add(productCode);
		}
		return new List<String>(productCodes);
	}

	@AuraEnabled
	public static String invokeLicenseEventService(
		String licenseDetails,
		String productCodes,
		Id serverDeploymentId
	) {
		Server_Deployment__c serverDeployment = getServerDeployment(serverDeploymentId);
		List<ServerDeploymentLicenseDataModel.Suite> suites = (List<ServerDeploymentLicenseDataModel.Suite>) JSON.deserialize(
			licenseDetails,
			List<ServerDeploymentLicenseDataModel.Suite>.class
		);

		List<String> productCodesDeserialized = (List<String>) JSON.deserialize(
			productCodes,
			List<String>.class
		);

		List<ServerDeploymentLicenseDataModel.Bundle> bundles = new List<ServerDeploymentLicenseDataModel.Bundle>();
		for (String productCode : productCodesDeserialized) {
			bundles.add(new ServerDeploymentLicenseDataModel.Bundle(productCode));
		}

		ServerDeploymentLicenseDataModel.LicenseEventRequestPayload payload = buildPayload(
			serverDeployment,
			suites,
			bundles
		);
		String stringPayload = JSON.serializePretty(payload).replace('null', '""');

		HttpResponse response = invokeLicensingAPI(stringPayload, serverDeploymentId);
		EnhancedReturnType rt = processLicensingAPIResponse(
			serverDeployment,
			serverDeploymentId,
			response,
			suites,
			bundles
		);
		insertIntegrationCalloutLog(serverDeploymentId, stringPayload, response, rt.retData);
		return JSON.serialize(rt);
	}

	private static Server_Deployment__c getServerDeployment(Id serverDeploymentId) {
		return [
			SELECT
				Id,
				Account__r.Name,
				Account__r.Id,
				Account__r.Domain__c,
				Account__r.Deployment_Method__c,
				Account__r.Type,
				RecordTypeId,
				Account__r.Healthcheck_Available_Picklist__c,
				Server_Device_Type__c,
				Tanium_Cloud_Admin__r.Email,
				License_delivery_email_primary__c,
				Cloud_Region__c,
				Cloud_Provider__c,
				Server_Hostnames__c,
				Vanity_URL__c,
				Type__c,
				Compliance_Framework__c,
				Sales_Order__c,
				Is_Titankube_Integration_Required__c,
				License_Notes__c,
				Country__r.Name
			FROM Server_Deployment__c
			WHERE Id = :serverDeploymentId
		];
	}

	private static ServerDeploymentLicenseDataModel.LicenseEventRequestPayload buildPayload(
		Server_Deployment__c serverDeployment,
		List<ServerDeploymentLicenseDataModel.Suite> suites,
		List<ServerDeploymentLicenseDataModel.Bundle> bundles
	) {
		ServerDeploymentLicenseDataModel.LicenseEventRequestPayload payload = new ServerDeploymentLicenseDataModel.LicenseEventRequestPayload();
		payload.licenseType = 'Customer';
		payload.company = 'Tanium';
		payload.version = '0';
		payload.environment = serverDeployment.Type__c;
		payload.name = serverDeployment.Account__r.Name;
		payload.customerId = serverDeployment.Account__r.Id;
		payload.deploymentId = serverDeployment.Id;
		payload.countryName = serverDeployment.Country__r.Name;
		payload.notes = serverDeployment.License_Notes__c;
		payload.infrastructure = serverDeployment.Server_Device_Type__c;
		payload.dataSharing = getPayloadDataSharing(serverDeployment);
		payload.hideCustomer = false;
		payload.titankube = (serverDeployment.Is_Titankube_Integration_Required__c == 'Yes');
		payload.entitlementType = 'GA';
		payload.cloudRegion = serverDeployment.Cloud_Region__c;
		payload.cloudProvider = serverDeployment.Cloud_Provider__c;
		payload.fedramp = false;
		payload.taasAdminEmail = getPayloadTaasAdminEmail(serverDeployment);
		payload.domain = serverDeployment.Account__r.Domain__c;
		payload.hostnames = serverDeployment.Server_Hostnames__c;
		payload.complianceFramework = serverDeployment.Compliance_Framework__c;
		payload.pocId = '';
		payload.suites = suites;
		payload.bundles = bundles;
		return payload;
	}

	@TestVisible
	private static Boolean getPayloadDataSharing(Server_Deployment__c serverDeployment) {
		return (serverDeployment.RecordTypeId == taasRecTypeId)
			? true
			: (serverDeployment.Account__r.Healthcheck_Available_Picklist__c == 'Yes') ? true : false;
	}

	@TestVisible
	private static String getPayloadTaasAdminEmail(Server_Deployment__c serverDeployment) {
		return (serverDeployment.RecordTypeId == onPremRecTypeId)
			? serverDeployment.License_Delivery_Email_Primary__c
			: serverDeployment.Tanium_Cloud_Admin__r.Email;
	}

	private static HttpResponse invokeLicensingAPI(String payload, Id recordId) {
		HttpRequest request = new HttpRequest();
		request.setEndpoint('callout:' + getEndpoint());
		request.setMethod('POST');
		request.setBody(payload);

		Http http = new Http();
		HttpResponse response = new HttpResponse();
		try {
			response = http.send(request);
		} catch (Exception e) {
			Logger.error('ServerDeploymentController.invokeLicensingAPI ERROR', recordId, e);
			Logger.saveLog();
			response.setStatusCode(401);
			response.setBody('{"error":"' + e.getMessage().replace('"', '') + '"}');
		}
		return response;
	}

	private static String getEndpoint() {
		String namedCredential = Utility.isSandbox()
			? 'License_Service_Sandbox'
			: 'License_Service_Prod';
		return namedCredential + System.Label.CreateEvent_LicenseServiceURL;
	}

	private static EnhancedReturnType processLicensingAPIResponse(
		Server_Deployment__c serverDeployment,
		Id recordId,
		HttpResponse response,
		List<ServerDeploymentLicenseDataModel.Suite> suites,
		List<ServerDeploymentLicenseDataModel.Bundle> bundles
	) {
		EnhancedReturnType rt = new EnhancedReturnType();
		ServerDeploymentLicenseDataModel.LicenseEventResponsePayload licenseResponse;
		String licensedModules = '';
		String calloutError = '';
		String licenseIntegrationError = '';

		if (response?.getStatusCode() == SUCCESSFUL_RESPONSE_CODE) {
			licenseResponse = (ServerDeploymentLicenseDataModel.LicenseEventResponsePayload) JSON.deserialize(
				response?.getBody(),
				ServerDeploymentLicenseDataModel.LicenseEventResponsePayload.class
			);
			licensedModules = generateLicenseModules(suites, serverDeployment, bundles);
			updateLicensingFields(serverDeployment.Id, licenseResponse.Id, licensedModules);

			rt.retResult = true;
			rt.retData = 'Success';
		} else {
			calloutError = logCalloutError(response?.getBody(), recordId);
			licenseIntegrationError = buildLicenseIntegrationError(response);
			updateLicensingFields(serverDeployment.Id, null, licenseIntegrationError);

			rt.retResult = false;
			rt.retData = calloutError;
		}
		return rt;
	}

	private static void updateLicensingFields(
		Id serverDeploymentId,
		Integer licenseId,
		String licensingMessage
	) {
		Server_Deployment__c serverDeployment = new Server_Deployment__c(Id = serverDeploymentId);

		if (licenseId != null) {
			licensingMessage = licensingMessage.replace(LICENSE_NOTES_DELIMITER, '\n')
				.replace(LICENSE_ID_PLACEHOLDER, String.valueOf(licenseId));
			serverDeployment.Licensed_Modules__c = licensingMessage;
			serverDeployment.License_Generated_By__c = UserInfo.getUserId();
			serverDeployment.License_Generated_DateTime__c = System.now();
			serverDeployment.License_Integration_Error__c = null;
		} else {
			serverDeployment.Licensed_Modules__c = null;
			serverDeployment.License_Integration_Error__c = licensingMessage;
		}

		try {
			Database.SaveResult updateResult = Database.update(serverDeployment, false);
		} catch (Exception e) {
			Logger.error(
					'ServerDeploymentController.updateLicensingFields ERRORS',
					serverDeployment,
					e
				)
				.setRecordId(serverDeploymentId)
				.addTag('apex');
			Logger.saveLog();
		}
	}

	private static String logCalloutError(String responseBody, Id recordId) {
		Map<String, Object> errorInfo = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
		String errorMsg = (String) errorInfo.get('error');
		Logger.error(
				'ServerDeploymentController.logCalloutError ERROR: \n' +
				'Licensing API Service returned an error: ' +
				errorMsg,
				recordId
			)
			.addTag('apex')
			.addTag('callout');
		Logger.saveLog();
		return errorMsg;
	}

	private static String buildLicenseIntegrationError(HTTPResponse response) {
		return 'Error Type: HTTP error\n' +
			'Error Message: ' +
			response.getStatusCode() +
			' ' +
			response.getStatus() +
			'\n' +
			response.getBody();
	}

	private static void insertIntegrationCalloutLog(
		Id recordId,
		String payload,
		HttpResponse response,
		String errorMessage
	) {
		Integration_Callout__c integCallout = new Integration_Callout__c(
			Name = 'Licensing API Callout - ' + recordId,
			Endpoint__c = getEndpoint(),
			Payload__c = payload,
			Response__c = response?.getBody(),
			Status_Code__c = String.valueOf(response.getStatusCode()),
			ErrorMessage__c = errorMessage
		);

		try {
			Database.SaveResult insertResult = Database.insert(integCallout, false);

			Server_Deployment__c serverDeployment = new Server_Deployment__c(Id = recordId);
			serverDeployment.Payload_sent_to_License_Server__c = integCallout.Id;

			Database.SaveResult updateResult = Database.update(serverDeployment, false);
		} catch (Exception e) {
			Logger.error(
					'ServerDeploymentController.insertIntegrationCalloutLog ERRORS',
					integCallout,
					e
				)
				.setRecordId(recordId)
				.addTag('apex');
			Logger.saveLog();
		}
	}

	private static String generateLicenseModules(
		List<ServerDeploymentLicenseDataModel.Suite> suites,
		Server_Deployment__c serverDeployment,
		List<ServerDeploymentLicenseDataModel.Bundle> bundles
	) {
		String licenseModules = '';
		licenseModules += serverDeployment.Sales_Order__c == null
			? ''
			: 'Sales Order ' + serverDeployment.Sales_Order__c;
		licenseModules += LICENSE_NOTES_DELIMITER;
		licenseModules += 'License ID ' + LICENSE_ID_PLACEHOLDER;
		licenseModules += convertSuitesToString(suites);
		licenseModules += convertBundlesToString(bundles);

		return licenseModules.length() > LICENSED_MODULES_MAX_SIZE
			? licenseModules.substring(0, LICENSED_MODULES_MAX_SIZE)
			: licenseModules;
	}

	private static String convertSuitesToString(
		List<ServerDeploymentLicenseDataModel.Suite> suites
	) {
		String stringSuites = '';
		for (ServerDeploymentLicenseDataModel.Suite suite : suites) {
			stringSuites += LICENSE_NOTES_DELIMITER;
			stringSuites +=
				suite.name +
				' ' +
				suite.quantity +
				' ' +
				suite.quantityType +
				' ' +
				suite.start +
				' to ' +
				suite.expiry +
				'; ';
		}
		return stringSuites.trim();
	}

	private static String convertBundlesToString(
		List<ServerDeploymentLicenseDataModel.Bundle> bundles
	) {
		String stringBundles = '';
		for (ServerDeploymentLicenseDataModel.Bundle bundle : bundles) {
			stringBundles += LICENSE_NOTES_DELIMITER;
			stringBundles += bundle.productCode + ' ';
		}
		return stringBundles.trim();
	}

	public class LicenseDetails {
		@AuraEnabled
		public String name { get; set; }
		@AuraEnabled
		public Integer quantity { get; set; }
		@AuraEnabled
		public String quantityType { get; set; }
		@AuraEnabled
		public Date start { get; set; }
		@AuraEnabled
		public Date expiry { get; set; }
		@AuraEnabled
		public Boolean isAddon { get; set; }

		public LicenseDetails(String name, Decimal quantity, Date start, Date expiry) {
			this.name = name;
			this.quantity = Integer.valueOf(quantity);
			this.quantityType = name == 'Screen Sharing' ? 'operators' : 'seats';
			this.start = start;
			this.expiry = expiry;
			this.isAddon = false;
		}
	}
}