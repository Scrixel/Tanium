@isTest
public with sharing class RoscoCmtyGuestTest {
    public RoscoCmtyGuestTest() {

    }

	@isTest(SeeAllData=false)
	static void test_Functional_NewUknown() {   


		Knowledge__kav article = new Knowledge__kav(
			Title = 'ROSCOTESTCASE Tanium Server',
			Summary = 'ROSCOTESTCASE',
			UrlName = 'urlname',
			Language = 'en_US',
			IsVisibleInCsp = true,
			IsVisibleInPkb = true,
			IsVisibleInPrm = true
		);
		insert article;		

		String netId = [SELECT Name FROM Network WHERE Name='Tanium Customer Community'].Id;
		
		Topic topic = new Topic(
			Name = 'foo',
			NetworkId = netId
		);
		insert topic;        
        
        RoscoCmtyGuest.getRequireLoginInit('https://foo.com/article/urlname');



    }

}