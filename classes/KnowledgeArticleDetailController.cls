/**
 * @Business: Controller class for the LTNG component - KnowledgeArticledetail
 * @Author: Cumulus Vision
 * Modified    ModifiedDate    Description
 * TAN-852      2020-04-09      Initial Development
 * TAN-913      2020-07-29      Added "UPDATE VIEWSTAT" clause while fetching the Knowledge record to maintain the
 *                              ViewCount field of KnowledgeArticleViewStat record.
 * TAN-919      2020-09-16      Returned the "Comments Link" Visibility information.
 * TAN-1004     2020-11-04      Returned the visibility information for different components
 */
public class KnowledgeArticleDetailController {
	@AuraEnabled
	public static ActionResult fetchKnowledgeArticle(Id kaId) {
		ActionResult result = new ActionResult();

		try {
			final String[] kaFieds = new List<String>{
				'Title',
				'ArticleNumber',
				'RecordType.Name',
				'FirstPublishedDate',
				'LastPublishedDate',
				'UrlName',
				'Article_Body__c',
				'Blog_Author__r.Name'
			};

			final String kaQuery =
				'SELECT ' +
				String.join(kaFieds, ', ') +
				', (SELECT DataCategoryGroupName, toLabel(DataCategoryName) FROM DataCategorySelections)' +
				' FROM Knowledge__kav' +
				' WHERE Id = :kaId' +
				' UPDATE VIEWSTAT';

			List<Knowledge__kav> listKnowledgeArticle = Database.query(kaQuery);

			if (listKnowledgeArticle.isEmpty()) {
				result.setFailure('Knowledge Article Not Found.');
				return result;
			}

			Knowledge__kav knowledgeArticle = listKnowledgeArticle[0];
			Map<String, Object> mapArticleConfigAttribute = fetchKnowledgeArticleConfiuration(
				knowledgeArticle.DataCategorySelections
			);

			Map<String, Object> mapData = new Map<String, Object>{
				'knowledgeArticle' => knowledgeArticle,
				'articleConfig' => mapArticleConfigAttribute,
				'topicIds' => getTopicIds(kaId)
			};
			result.setSuccess(mapData);
		} catch (Exception ex) {
			result.setFailure(ex);
			logException(ex);
		}

		return result;
	}

	private static Map<String, Object> fetchKnowledgeArticleConfiuration(
		List<Knowledge__DataCategorySelection> listDataCategorySelection
	) {
		Map<String, Object> mapConfigNameToValue = new Map<String, Object>{
			'isArticleNumberVisible' => false,
			'isCommentsLinkVisible' => false,
			'isSocialSharingAllowed' => false
		};

		Map<String, Knowledge_Article_Detail_Config__mdt> mapDataCategoryNameToKADC = new Map<String, Knowledge_Article_Detail_Config__mdt>();

		List<Knowledge_Article_Detail_Config__mdt> listKnowledgeArticleConfig = [
			SELECT
				Data_Category_Group_Unique_Name__c,
				Is_Article_Number_Visible__c,
				Is_Comments_Link_Visible__c,
				Is_Social_Sharing_Allowed__c
			FROM Knowledge_Article_Detail_Config__mdt
		];
		for (Knowledge_Article_Detail_Config__mdt kadc : listKnowledgeArticleConfig) {
			mapDataCategoryNameToKADC.put(kadc.Data_Category_Group_Unique_Name__c, kadc);
		}

		for (Knowledge__DataCategorySelection dcSelection : listDataCategorySelection) {
			String dataCategoryGroupName = dcSelection.DataCategoryGroupName;

			if (mapDataCategoryNameToKADC.containsKey(dataCategoryGroupName)) {
				Knowledge_Article_Detail_Config__mdt kadc = mapDataCategoryNameToKADC.get(
					dataCategoryGroupName
				);
				mapConfigNameToValue.put('isArticleNumberVisible', kadc.Is_Article_Number_Visible__c);
				mapConfigNameToValue.put('isCommentsLinkVisible', kadc.Is_Comments_Link_Visible__c);
				mapConfigNameToValue.put('isSocialSharingAllowed', kadc.Is_Social_Sharing_Allowed__c);
				break;
			}
		}

		return mapConfigNameToValue;
	}

	/** getArticleFromURL
	 */
	public static String getArticleIdFromUrl(String url) {
		String ret = 'Sorry, article was not found!';

		try {
			String kbUrl = 't-b-d';

			if (url.containsIgnoreCase('?kburl=')) {
				List<String> aUrl = url.split('=');
				kbUrl = aUrl[aUrl.size() - 1];
			} else {
				List<String> aUrl = url.split('/');
				kbUrl = aUrl[aUrl.size() - 1];
			}

			String soql =
				'SELECT Id' +
				',Title' +
				',Summary ' +
				',Article_Body__c' +
				',FirstPublishedDate' +
				',LastPublishedDate ' +
				',RecordType.Name ' +
				',UrlName ' +
				'FROM Knowledge__kav ' +
				'WHERE UrlName = \'' +
				kbUrl +
				'\' ' +
				'AND PublishStatus = \'Online\' ' +
				'UPDATE VIEWSTAT';

			System.debug('soql:' + soql);

			List<Knowledge__kav> kbs = Database.query(soql);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					ret = kb.Id;
				}
			}
		} catch (Exception e) {
			System.debug('getArticleFromURL: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}	

	/** getArticleInit
	 */
	@AuraEnabled
	public static Map<String, String> getArticleInit(String articleId) {
		Map<String, String> ret = new Map<String, String>();
		ret.put('Id', '');
		ret.put('Title', 'Sorry, article was not found!');
		ret.put('Summary', 'Sorry, article was not found!!');
		ret.put('Body', 'Sorry, article was not found!!!');
		ret.put('iFrameURL', '');
		ret.put('URL', '');

		try {
			String whereClause = '';
			if (articleId.left(2) == 'ka') {
				whereClause = 'AND Id = \'' + articleId + '\'';
			} else if (articleId.containsIgnoreCase('https://')) {
				whereClause = 'AND Id = \'' + getArticleIdFromUrl(articleId) + '\'';
			} else {
				whereClause = 'AND ArticleNumber = \'' + articleId + '\'';
			}

			String soql =
				'SELECT ArticleNumber' +
				',Title' +
				',Summary ' +
				',Article_Body__c' +
				',FirstPublishedDate' +
				',LastPublishedDate ' +
				',RecordType.Name ' +
				',UrlName ' +
				'FROM Knowledge__kav ' +
				'WHERE PublishStatus = \'Online\' ' +
				whereClause +
				' ' +
				'UPDATE VIEWSTAT';

			System.debug('soql:' + soql);

			List<Knowledge__kav> kbs = Database.query(soql);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					ret.put('Id', kb.Id);
					ret.put('Title', kb.Title);
					ret.put('Summary', kb.Summary);
					ret.put('Body', String.valueOf(kb.Article_Body__c));
					ret.put('iFrameURL', '');
					ret.put('URL', kb.UrlName);
					//ret.put('FirstPublishedDate',formatGmt(kb.FirstPublishedDate));
					//ret.put('LastPublishedDate', formatGmt(kb.LastPublishedDate));
				}
				

			}

		} catch (Exception e) {
			System.debug('getArticleInit: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	
	public static String getTopicIds(String kaId){

		String ret = '';

		try {
			String soql = 'SELECT TopicId ' + 
					'FROM TopicAssignment ' + 
					'WHERE EntityId  = \'' + kaId + '\' ';

			System.debug('soql:' + soql);
			List<TopicAssignment> assignments = Database.query(soql);

			if (!assignments.isEmpty()) {
				for(TopicAssignment a: assignments){
					ret = ret =='' ? String.valueOf(a.TopicId) : ret + ',' + String.valueOf(a.TopicId);
				}
			}
		} catch (Exception e) {
			System.debug('getTopicIds: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}		

		return ret;


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

	@AuraEnabled
	public static List<Map<String,String>> getKnowledgeObjectsForTesting() {

		List<Map<String,String>> ret = new List<Map<String,String>>();

		// Query to provide additional info
		String soql = 'SELECT ArticleNumber, ' +
                        'Title, ' +
                        'Summary, ' +
                        'Article_Body__c ' +
                        'FROM Knowledge__kav ' +
                        'ORDER BY ArticleNumber DESC';
		
		System.debug('SOQL: ' + soql);
		List<Knowledge__kav> kbs = Database.query(soql);
		

		for(Knowledge__kav kb: kbs){

			Map<String,String> obj = new Map<String,String>();

            obj.put('ArticleNumber', kb.ArticleNumber);
            obj.put('Title', kb.Title);
            obj.put('Summary', kb.Summary);
            obj.put('Article_Body__c', kb.Article_Body__c);
            
            ret.add(obj);
		}			

		return ret;

	}		
}