public without sharing class RoscoHomePageNoShare {

    public static String getRecentCommentIds(String daysBack){

        String ret = '\'\'';

        String userId = UserInfo.getUserId();

		String soql =
			'SELECT ParentId ' +
			'FROM FeedComment ' +
			'WHERE CreatedDate = LAST_N_DAYS:' + daysBack + ' ' +
			'AND CreatedById = \'' + userId + '\' ' +
			'';

		System.debug('SOQL: ' + soql);
		List<FeedComment> comments = Database.query(soql);
		System.debug(comments);

		// Loop through and return
		if (comments.size() != 0) {
            for (FeedComment c : comments) {

				if(!ret.contains(String.valueOf(c.ParentId))){
					if(ret == '\'\''){
                        ret = '\'' + c.ParentId + '\'';
                    } else {
                        ret += ',\'' + c.ParentId + '\'';
                    }
				}                
            }
        }

        return ret;

    }
}