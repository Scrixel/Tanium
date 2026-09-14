/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Support class to decrypt private keys
 * @Author: Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-11659   2025-09-14    Created the class
 * SS-13542   2026-06-30    Added ServiceNowIntegrationUrl functionality
 *
 */
public without sharing class CryptoUtility {
	private static Boolean isValidRequest(String functionality) {
		Set<String> validfunctionalities = new Set<String>{
			'TestClassKey',
			'UserVoiceIntegrationKey',
			'ServiceNowIntegrationKey'
		};
		return validfunctionalities.contains(functionality);
	}

	private static Blob getPrivateKey(String feature) {
		Private_Key__c privateKeysRecord = [
			SELECT Id, Key__c
			FROM Private_Key__c
			WHERE Feature__c = :feature AND IsActive__c = TRUE
			WITH SYSTEM_MODE
			LIMIT 1
		];
		return Blob.valueOf(privateKeysRecord.Key__c);
	}

	public static String encryptData(String dataToEncrypt, String feature) {
		if (!isValidRequest(feature)) {
			return null;
		}
		Blob key = getPrivateKey(feature);
		Blob encryptedData = Crypto.encryptWithManagedIV('AES128', key, Blob.valueOf(dataToEncrypt));
		return EncodingUtil.base64Encode(encryptedData);
	}

	public static String decryptData(String encryptedData, String feature) {
		if (!isValidRequest(feature)) {
			return null;
		}
		Blob key = getPrivateKey(feature);
		Blob decodedEncryptedData = EncodingUtil.base64Decode(encryptedData);
		Blob decryptedData = Crypto.decryptWithManagedIV('AES128', key, decodedEncryptedData);
		return decryptedData.toString();
	}
}