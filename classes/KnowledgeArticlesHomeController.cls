/**
 * @Business: Controller class for the LTNG component - KnowledgeArticlesHome
 * @Author: Cumulus Vision
 * Modified    ModifiedDate    Description
 *  TAN-851    2019-03-31      Initial Development
 *  TAN-868    2020-04-08      Displayed most recent articles first, sorted by FirstPublishDate field
 *  TAN-918    2020-08-26      Modified fetchKnowledgeArticles method to work with "Data Category Group Unique Name"
 *                             parameter.
 */
public class KnowledgeArticlesHomeController {
	private static final String PUBLISH_STATUS_ONLINE = 'Online';

	@AuraEnabled
	public static ActionResult isCommunitySession() {
		ActionResult result = new ActionResult();

		try {
			Map<String, Object> mapData = new Map<String, Object>{
				'isCommunity' => String.isNotBlank(Site.getSiteId())
			};

			result.setSuccess(mapData);
		} catch (Exception ex) {
			result.setFailure(ex);
			logException(ex);
		}

		return result;
	}

	@AuraEnabled
	public static ActionResult fetchKnowledgeArticles(
		Integer pageNumber,
		Integer recordsPerPage,
		String dataCategoryGroupUniqueName
	) {
		ActionResult result = new ActionResult();

		try {
			List<String> listPublishStatus = new List<String>{ PUBLISH_STATUS_ONLINE };
			final Integer RECORD_OFFSET = (pageNumber - 1) * recordsPerPage;
			final Integer TOTAL_KA_RECORDS = getTotalKnowledgeArticles(
				listPublishStatus,
				dataCategoryGroupUniqueName
			);
			final Integer TOTAL_PAGES = computeTotalPages(TOTAL_KA_RECORDS, recordsPerPage);
			final String[] kaFieds = new List<String>{
				'Title',
				'RecordType.Name',
				'FirstPublishedDate',
				'Summary',
				'UrlName',
				'Blog_Author__r.Name'
			};

			String dataCategoryGroupFilter = buildDataCategoryGroupFilter(dataCategoryGroupUniqueName);

			final String kaQuery =
				'SELECT ' +
				String.join(kaFieds, ', ') +
				', (SELECT toLabel(DataCategoryName) FROM DataCategorySelections)' +
				' FROM Knowledge__kav' +
				' WHERE PublishStatus = :PUBLISH_STATUS_ONLINE' +
				(String.isBlank(dataCategoryGroupFilter) ? '' : dataCategoryGroupFilter) +
				' ORDER BY FirstPublishedDate DESC' +
				' LIMIT :recordsPerPage' +
				' OFFSET :RECORD_OFFSET';

			System.debug('\n kaQuery: ' + kaQuery);
			List<Knowledge__kav> listKnowledgeArticle = Database.query(kaQuery);
			Map<String, Object> mapData = new Map<String, Object>{
				'knowledgeArticles' => listKnowledgeArticle,
				'totalPages' => TOTAL_PAGES
			};

			result.setSuccess(mapData);
		} catch (Exception ex) {
			result.setFailure(ex);
			logException(ex);
		}

		return result;
	}

	private static Integer getTotalKnowledgeArticles(
		List<String> listPublishStatus,
		String dataCategoryGroupUniqueName
	) {
		String dataCategoryGroupFilter = buildDataCategoryGroupFilter(dataCategoryGroupUniqueName);

		String kaCountQuery =
			'SELECT COUNT() FROM Knowledge__kav' +
			(listPublishStatus.isEmpty() ? '' : ' WHERE PublishStatus IN :listPublishStatus') +
			(String.isBlank(dataCategoryGroupFilter) ? '' : dataCategoryGroupFilter);

		System.debug('\n kaCountQuery: ' + kaCountQuery);
		Integer kaCount = Database.countQuery(kaCountQuery);
		return kaCount;
	}

	private static String buildDataCategoryGroupFilter(String dataCategoryGroupUniqueName) {
		String dataCategorySOQLFilter;
		if (String.isNotBlank(dataCategoryGroupUniqueName)) {
			dataCategoryGroupUniqueName += '__c';
			dataCategorySOQLFilter =
				' WITH DATA CATEGORY ' +
				dataCategoryGroupUniqueName +
				' BELOW ALL__c';
		}

		return dataCategorySOQLFilter;
	}

	private static Integer computeTotalPages(Integer totalRecords, Integer recordsPerPage) {
		Integer totalPages = totalRecords / recordsPerPage;
		totalPages += Math.mod(totalRecords, recordsPerPage) > 0 ? 1 : 0;
		return totalPages;
	}

	public static void logException(Exception ex) {
		System.debug('\n Error:' + ex.getMessage() + '\n Stack Trace:' + ex.getStackTraceString());
	}

	public class ActionResult {
		@AuraEnabled
		public Boolean isSuccess;

		@AuraEnabled
		public String error;

		@AuraEnabled
		public Object data;

		public void setSuccess(Map<String, Object> mapData) {
			isSuccess = true;
			error = null;
			data = mapData;
		}

		public void setFailure(String errorMessage) {
			isSuccess = false;
			error = errorMessage;
			data = null;
		}

		public void setFailure(Exception ex) {
			isSuccess = false;
			error = ex.getMessage();
			data = new Map<String, String>{ 'errorDetails' => ex.getStackTraceString() };
		}
	}
}