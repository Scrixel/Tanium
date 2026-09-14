/**
 * @Business: Salesforce CPQ Rest API (QuoteCalculator) support class
 * @Authors:  Salesforce
 * RequestId  ModifiedDate  Description
 * SS-6987    2024-01-04    Created the class (https://developer.salesforce.com/docs/atlas.en-us.cpq_dev_api.meta/cpq_dev_api/cpq_quote_api_save_final.htm)
 */
public without sharing class SBQQ_QuoteSaver {
	public SBQQ_ApiDataModels.QuoteModel save(SBQQ_ApiDataModels.QuoteModel quote) {
		String quoteJSON = SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', JSON.serialize(quote));
		return (SBQQ_ApiDataModels.QuoteModel) JSON.deserialize(
			quoteJSON,
			SBQQ_ApiDataModels.QuoteModel.class
		);
	}
}