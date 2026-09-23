public with sharing class LightningResponse {
	@AuraEnabled
	public Boolean isSuccess;

	@AuraEnabled
	public Object data;

	@AuraEnabled
	public String message;

	public LightningResponse() {
		isSuccess = false;
		data = null;
		message = '';
	}
}