/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Class that contains constants used by other classes
 * @Date:     2025-02-28
 * @Author:   Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-10251   2025-02-28    Created the class
 * SS-8303    2025-03-06    Added constant COMMUNITY_PLAYBOOK_IDEAS_ID
 * SS-10546   2025-03-25    Added constant PARTNER_CASE_ACCESS
 * SS-10404   2025-03-11    Added constants ZOOMIN_COMMUNITY_CLOUD_PERM_SET, TANIUM_COMMUNITY_UNKNOWN_PROFILE
 * SS-10474   2025-05-15    Added constant TANIUM_DSA_USER_ID
 * SS-11999   2025-11-03    Added constant TANIUM_CUSTOMER_COMMUNITY, TANIUM_CUSTOMER_COMMUNITY_ID
 * SS-12082   2025-11-19    Added constant CUSTOMER_COMMUNITY_MANAGER_ID
 * SS-12298   2026-01-13    Added constant CASE_CLOSE_STATUSES, CASE_CLOSE_SUMMARY
 * SS-12496   2026-02-24    Added constant DELETE_LEADS_AND_CONTACTS_PERMISSION
 * SS-12847   2026-03-27    Added constant SALES_SYSTEMS_USER_ID
 * SS-13423   2026-06-24    Added constant SERVICE_CLOUD_TANIUM_USER_ID
 * SS-13834   2026-08-24    Added constant PAID_AI_CREDIT_PRODUCT_CODES
 */
public without sharing class Constants {
	public static final String TANIUM_DEVELOPER_USERS_PERM_SET = 'Tanium_Developer_Users';
	public static final String CONSTELLANT_DEV_PERM_SET = 'Constellant_DEV';
	public static final String COMMUNITY_PLAYBOOK_IDEAS_ID = '09aRO00000004YH';
	public static final String PARTNER_CASE_ACCESS = 'Partner_Case_Access';
	public static final String ZOOMIN_COMMUNITY_CLOUD_PERM_SET = 'Zoomin_for_Community_Cloud_user_permission_set';
	public static final String TANIUM_COMMUNITY_UNKNOWN_PROFILE = 'Tanium Community Login Unknown';
	public static final String TANIUM_DSA_USER_ID = '0057V000009uWezQAE';
	public static final String TANIUM_CUSTOMER_COMMUNITY = 'Tanium Customer Community';
	public static final String TANIUM_CUSTOMER_COMMUNITY_ID = [
		SELECT Id
		FROM Network
		WHERE Name = :TANIUM_CUSTOMER_COMMUNITY
		LIMIT 1
	]
	.Id;
	public static final Id CUSTOMER_COMMUNITY_MANAGER_ID = [
		SELECT Id
		FROM User
		WHERE Alias = 'jliao' AND UserType = 'Standard' AND IsActive = TRUE
		LIMIT 1
	]
	.Id;
	public static final List<String> CASE_CLOSE_STATUSES = new List<String>{
		'Closed',
		'Closed as Duplicate'
	};
	public static final String CASE_CLOSE_SUMMARY = 'Case Close Summary:';
	public static final String DELETE_LEADS_AND_CONTACTS_PERMISSION = 'Can_Delete_Leads_and_Contacts';
	public static final Id SALES_SYSTEMS_USER_ID = [
		SELECT Id
		FROM User
		WHERE Alias = 'ssystems' AND IsActive = TRUE
		LIMIT 1
	]
	.Id;
	public static final Id SERVICE_CLOUD_TANIUM_USER_ID = [
		SELECT Id
		FROM User
		WHERE Alias = 'tanium' AND UserType = 'Standard' AND IsActive = TRUE
		LIMIT 1
	]
	.Id;
	public static final List<String> PAID_AI_CREDIT_PRODUCT_CODES = new List<String>{
		'TANIUM-AI-CREDITS-CLOUD',
		'TANIUM-AI-CREDITS-CLOUDGOV-US'
	};
}