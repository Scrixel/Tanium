@isTest
public with sharing class RoscoCmtyRdrTest {

    
    @isTest(SeeAllData=true) static void test_Unit_getRdrUrl() {

        String netId = [SELECT Name FROM Network WHERE Name='Tanium Customer Community'].Id;
        String baseUrl = Network.getLoginUrl(netId).replace('login', '');
        String rUrl = RoscoCmtyRdr.getRdrUrl(baseurl + '/kb?foo');
        System.debug(rUrl); //bump

    }

    @isTest(SeeAllData=true) static void test_Unit_getKBArticleId() {

        List<Knowledge__kav> kb = [
            SELECT UrlName
            FROM Knowledge__kav
            WHERE PublishStatus = 'Online'
            LIMIT 1
        ];

        if(kb.size() > 0){

            String ret = RoscoCmtyRdr.getKBArticleId(kb[0].UrlName);
            System.debug(ret);
        }

    }    
}