/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public class x7sIdeasNotifyModelTest {

	@IsTest static void testModel() {
		x7sIdeasNotifyModel notifyModel = new x7sIdeasNotifyModel('0123456789012345', 'nameVariable', 'contextVariable', 'detailVariable', 'urlVariable');
		System.assertNotEquals(null, notifyModel);
		notifyModel.Dump('Testing dump: ');
	}
}