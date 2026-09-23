public with sharing class RoscoCmtyGuest {

    /** getRequireLoginInit
	 * getRequireLoginInit description
	 * @return   return description
	 */
	@AuraEnabled
	public static Map<String, String> getRequireLoginInit(String url) {

		Map<String, String> ret = new Map<String, String>();

		try {
			ret.put('Name', UserInfo.getUserName());
            ret.put('topicIds', getTopicIdsFromUrl(url));

		} catch (Exception e) {
			System.debug('getRequireLoginInit: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

    public static String getTopicIdsFromUrl(String url){

        String ret = '';

		try {

            if(url.containsIgnoreCase('/article/')){
                List<String> aUrl = url.split('/');
                String urlName = aUrl[aUrl.size()-1];

			    String soql = 'Select TopicId ' +
					'FROM TopicAssignment ' + 
                    'WHERE EntityId IN (' +
                        'SELECT Id ' +
                        'FROM Knowledge__kav ' +
                        'WHERE UrlName = \'' + urlName + '\')';
                    
                System.debug('soql:' + soql);
                List<TopicAssignment> assignments = Database.query(soql);

                if (!assignments.isEmpty()) {
                    for(TopicAssignment a: assignments){
                        ret = ret =='' ? String.valueOf(a.TopicId) : ret + ',' + String.valueOf(a.TopicId);
                    }
                }
            }

		} catch (Exception e) {
			System.debug('getTopicIdsFromUrl: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;        


    }

}