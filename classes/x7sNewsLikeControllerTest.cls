/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

/*
@Class Name          : x7sNewsLikeControllerTest
@Created by          :
@Description         : Apex Test class for x7sNewsLikeController
*/
@IsTest
private class x7sNewsLikeControllerTest
{

    //Hardcoded Network Id as we can't able to get get Network Id in Test classes.
    //Packaging org
    //public Static String strNetId = '0DB36000000PB5MGAW';

    public static String strNetId {
        get {
            return [SELECT Id FROM Network LIMIT 1][0].Id;
        }
    }

    // Fran Summer 17 org
    //public Static String strNetId = '0DBB0000000CayaOAC';

    @IsTest
    static void test_LikeUnlikeNews(){
        //create News Records
        X7S_News__c newsObj = x7sNewsUtilityTest.createNews(strNetId);
        X7S_News__c newsObj1 = x7sNewsUtilityTest.createNews(strNetId);

        Test.startTest();
        x7sNewsLikeController.likeNews(newsObj.Id);
        x7sNewsLikeController.likeNews(newsObj1.Id);
        System.assert(x7sNewsLikeController.likeNews(null) == false);

        List<X7S_News_Like__c> newsLikes = [
                SELECT Id
                FROM X7S_News_Like__c
                WHERE User__c = :UserInfo.getUserId()
        ];
        System.assert(newsLikes.size() == 2, 'Test news likes not matched');
        System.assert(x7sNewsLikeController.isLiking(newsObj.Id));

        x7sNewsLikeController.unLikeNews(newsObj.Id);
        x7sNewsLikeController.unLikeNews(newsObj1.Id);
        System.assert(x7sNewsLikeController.unLikeNews(null) == false);

        newsLikes = [
                SELECT Id
                FROM X7S_News_Like__c
                WHERE User__c = :UserInfo.getUserId()
        ];
        System.assert(newsLikes.isEmpty());

        Test.stopTest();
    }

}