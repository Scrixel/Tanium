/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Events Image Mock Utility.  Singleton responsible for creating the testing mock.
 */
public with sharing class x7sEventsImageMockUtil {
	private x7sEventsImageMockUtil() {
	} // NOPMD -- Required to implement the singleton pattern.

	/**
	 * @description Get instance of the Mock class
	 * @return x7sEventsImageMockProvider instance
	 */
	public static x7sEventsImageMockProvider getInstance() {
		return new x7sEventsImageMockProvider();
	}

	/**
	 * @description Create Mock
	 * @param typeToMock : Class to mock
	 * @return Object : Mock Object
	 */
	public static Object createMock(Type typeToMock) {
		return Test.createStub(typeToMock, x7sEventsImageMockUtil.getInstance());
	}
}