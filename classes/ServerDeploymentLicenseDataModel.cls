/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Data Model class for Server Deployment Licensing Event.
 * @Date:     2026-09-10
 * @Author:   Tanium Dev Team
 * ReuqestId  ModifiedDate   Description
 * SS-13774   2026-09-10     Initial development
 */
public class ServerDeploymentLicenseDataModel {
	public class Suite {
		@AuraEnabled
		public String name { get; set; }
		@AuraEnabled
		public Integer quantity { get; set; }
		@AuraEnabled
		public String quantityType { get; set; }
		@AuraEnabled
		public String start { get; set; }
		@AuraEnabled
		public String expiry { get; set; }
		@AuraEnabled
		public Boolean isAddon { get; set; }
	}

	public class Bundle {
		@AuraEnabled
		public String productCode { get; set; }

		public Bundle(String productCode) {
			this.productCode = productCode;
		}
	}

	public class LicenseEventRequestPayload {
		public String licenseType { get; set; }
		public String company { get; set; }
		public String version { get; set; }
		public String environment { get; set; }
		public String name { get; set; }
		public String customerId { get; set; }
		public String deploymentId { get; set; }
		public String countryName { get; set; }
		public String notes { get; set; }
		public String infrastructure { get; set; }
		public Boolean dataSharing { get; set; }
		public Boolean hideCustomer { get; set; }
		public Boolean titankube { get; set; }
		public String entitlementType { get; set; }
		public String cloudRegion { get; set; }
		public String cloudProvider { get; set; }
		public Boolean fedramp { get; set; }
		public String taasAdminEmail { get; set; }
		public String domain { get; set; }
		public String hostnames { get; set; }
		public String complianceFramework { get; set; }
		public String pocId { get; set; }
		public List<Suite> suites { get; set; }
		public List<Bundle> bundles { get; set; }
	}

	public class LicenseEventResponsePayload {
		public Integer Id { get; set; }
		public String licenseType { get; set; }
		public String company { get; set; }
		public String version { get; set; }
		public String environment { get; set; }
		public String name { get; set; }
		public String customerId { get; set; }
		public String deploymentId { get; set; }
		public String countryName { get; set; }
		public String notes { get; set; }
		public String infrastructure { get; set; }
		public Boolean dataSharing { get; set; }
		public Boolean hideCustomer { get; set; }
		public Integer federationCount { get; set; }
		public Boolean titankube { get; set; }
		public String entitlementType { get; set; }
		public String cloudRegion { get; set; }
		public String cloudProvider { get; set; }
		public Boolean fedramp { get; set; }
		public String taasAdminEmail { get; set; }
		public String domain { get; set; }
		public String hostnames { get; set; }
		public String complianceFramework { get; set; }
		public Boolean redacted { get; set; }
		public String redactedReason { get; set; }
		public String start { get; set; }
		public String expiry { get; set; }
		public String createdAt { get; set; }
		public String createdBy { get; set; }
		public String updatedAt { get; set; }
		public String updatedBy { get; set; }
		public String provisionerResult { get; set; }
		public String provisionedAt { get; set; }
	}
}