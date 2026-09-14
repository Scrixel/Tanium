/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

trigger x7sEventsFeedItemTrigger on FeedItem (after insert) {
    x7sEventsFeedItemTriggerHelper.handleEventsFeedItemInsert(Trigger.new);
}