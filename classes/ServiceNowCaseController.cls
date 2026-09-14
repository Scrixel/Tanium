/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Controller supporting LWC for ServiceNow Case Creation - POC
 * @Date:     2026-06-30
 * @Author:   Tanium Dev Team
 * ReuqestId  ModifiedDate  Description
 * SS-13542   2026-06-30    Created the class
 */
public with sharing class ServiceNowCaseController {
	@AuraEnabled(cacheable=false)
	public static IframeContext getIframeContext(String feature) {
		User user = [
			SELECT Id, AccountId, Email, Name
			FROM User
			WHERE Id = :UserInfo.getUserId()
			LIMIT 1
		];

		IframeContext ctx = new IframeContext();
		ctx.accountId = user.AccountId;
		ctx.ssoToken = generateToken(user, feature);
		return ctx;
	}

	@AuraEnabled
	public static String getBaseUrl() {
		return Utility.getInstanceSettingValue('ServiceNowIntegrationUrl');
	}

	@TestVisible
	private static String generateToken(User user, String feature) {
		DateTime inOneHour = DateTime.now().addMinutes(60);
		Map<String, Object> payload = new Map<String, Object>{
			'guid' => user.id,
			'email' => user.email,
			'display_name' => user.name,
			'expires' => inOneHour.toString()
		};
		String payloadJson = JSON.serialize(payload);
		String encryptedKey = Utility.getInstanceSettingValue(feature);
		String header = '{"alg":"HS256","typ":"JWT"}';
		String encodedHeader = EncodingUtil.base64Encode(Blob.valueOf(header));
		String encodedPayload = EncodingUtil.base64Encode(Blob.valueOf(payloadJson));
		/*	System.debug('CK22 encryptedKey ' + encryptedKey);
		System.debug('CK22 feature ' + feature);
		System.debug('CK22 encodedHeader ' + encodedHeader);
		System.debug('CK22 encodedPayload ' + encodedPayload);

		System.debug(
			'CK22 Blob.valueOf(encodedHeader + encodedPayload) ' +
			Blob.valueOf(encodedHeader + '.' + encodedPayload).toString()
		);
		System.debug(
			'CK22 Blob.valueOf(CryptoUtility.decryptData(encryptedKey, feature)) ' +
			Blob.valueOf(CryptoUtility.decryptData(encryptedKey, feature)).toString()
		);

		System.debug(
			'CK22 Crypto.generateMac ' +
			Crypto.generateMac(
				'HmacSHA256',
				Blob.valueOf(encodedHeader + '.' + encodedPayload),
				Blob.valueOf(CryptoUtility.decryptData(encryptedKey, feature))
			)
		);*/

		String signature = EncodingUtil.base64Encode(
			Crypto.generateMac(
				'HmacSHA256',
				Blob.valueOf(encodedHeader + '.' + encodedPayload),
				Blob.valueOf(CryptoUtility.decryptData(encryptedKey, feature))
			)
		);
		return (encodedHeader +
			'.' +
			encodedPayload +
			'.' +
			signature)
			.replace('+', '-')
			.replace('/', '_');
	}

	public class IframeContext {
		@AuraEnabled
		public String accountId;
		@AuraEnabled
		public String ssoToken;
	}
}