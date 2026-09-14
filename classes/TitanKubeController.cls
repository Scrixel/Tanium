/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Controller class for the TitanKube portal
 * @Authors: Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-11659   2025-07-09    Created the controller
 * SS-12068   2025-11-12    Added expires parameter to the token
 * SS-12416   2026-01-14    Ensure there is no whitespace in the signature
 * SS-12558   2026-02-02    Update method for removing whitespace from the token
 * SS-13094   2026-04-29    Update the token generation to replace non-valid URL characters
 */
public with sharing class TitanKubeController {
	@AuraEnabled
	public static String generateUserVoiceUrl(Id userId, String feature) {
		String token = generateUserVoiceToken(userId, feature);
		String baseUrl = Utility.getInstanceSettingValue('UserVoiceIntegrationUrl');
		return baseUrl + token;
	}

	@TestVisible
	private static String generateUserVoiceToken(Id userId, String feature) {
		DateTime inOneHour = DateTime.now().addMinutes(60);
		User user = [SELECT Id, Email, Name FROM User WHERE Id = :userId];
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
}