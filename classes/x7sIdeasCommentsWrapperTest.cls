/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */


@IsTest
private class x7sIdeasCommentsWrapperTest {
	@IsTest
	static void testWrapper() {
		x7sIdeasCommentsWrapper.CommentsModel commentModel = new x7sIdeasCommentsWrapper.CommentsModel();
		commentModel.newStatus = '';
		commentModel.changedBy = '';
		commentModel.changedById = '';
		commentModel.changedDate = Date.today();
		commentModel.commentText = '';

		System.assertNotEquals(null, commentModel);
	}
}