/**
 * @Business: Salesforce CPQ Rest API (CalculateCallback) support class
 * @Authors:  Salesforce
 * RequestId  ModifiedDate  Description
 * SS-6987    2024-01-04    Created the class (https://developer.salesforce.com/docs/atlas.en-us.cpq_dev_api.meta/cpq_dev_api/cpq_quote_api_calculate_final.htm)
 */
global without sharing class SBQQ_CalculateCallback implements SBQQ.CalculateCallback {
	// implementation of callback method
	global void callback(String quoteJSON) {
		SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', quoteJSON);
	}
}