/*
 * @BUSINESS: Allows for returning additional information (Boolean and String)
 * @DATE: 2024-04-23
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-7698    2024-04-23    Created the class
 * SS-10411   2025-03-08    AuraEnabled retResult and retData, removed inline comments
 */
public without sharing class EnhancedReturnType {
	@AuraEnabled
	public Boolean retResult { get; set; }
	@AuraEnabled
	public String retData { get; set; }

	public EnhancedReturnType() {
		retResult = null;
		retData = null;
	}

	public EnhancedReturnType(Boolean retResult) {
		this.retResult = retResult;
		this.retData = null;
	}

	public EnhancedReturnType(Boolean retResult, String retData) {
		this.retResult = retResult;
		this.retData = retData;
	}

	public EnhancedReturnType(String retData, Boolean retResult) {
		this(retResult, retData);
	}
}