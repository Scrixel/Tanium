/**
 * @Business: Salesforce CPQ Rest API (QuoteCalculator) support class
 * @Authors:  Salesforce
 * RequestId  ModifiedDate  Description
 * SS-6987    2024-01-04    Created the class (https://developer.salesforce.com/docs/atlas.en-us.cpq_dev_api.meta/cpq_dev_api/cpq_quote_api_calculate_final.htm)
 */
public without sharing class SBQQ_QuoteCalculator {
	public void calculate(SBQQ_ApiDataModels.QuoteModel quote, String callbackClass) {
		QuoteCalculatorContext ctx = new QuoteCalculatorContext(quote, callbackClass);
		SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteCalculator', null, JSON.serialize(ctx));
	}

	private class QuoteCalculatorContext {
		private SBQQ_ApiDataModels.QuoteModel quote;
		private String callbackClass;

		private QuoteCalculatorContext(SBQQ_ApiDataModels.QuoteModel quote, String callbackClass) {
			this.quote = quote;
			this.callbackClass = callbackClass;
		}
	}
}