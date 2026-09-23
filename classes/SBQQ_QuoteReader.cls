/**
 * @Business: Salesforce CPQ Rest API (QuoteCalculator) support class
 * @Authors:  Salesforce
 * RequestId  ModifiedDate  Description
 * SS-6987    2024-01-04    Created the class (https://developer.salesforce.com/docs/atlas.en-us.cpq_dev_api.meta/cpq_dev_api/cpq_api_read_quote.htm)
 */
public without sharing class SBQQ_QuoteReader {
	public SBQQ_ApiDataModels.QuoteModel read(String quoteId) {
		String quoteJSON = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quoteId);
		return (SBQQ_ApiDataModels.QuoteModel) JSON.deserialize(
			quoteJSON,
			SBQQ_ApiDataModels.QuoteModel.class
		);
	}
}