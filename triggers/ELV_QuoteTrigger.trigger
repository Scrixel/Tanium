/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Trigger on the standard Quote (Legacy Quote) object. All logic lives in
 *            QuoteTriggerHandler. Named with the ELV_ prefix because the Nue managed
 *            package already ships Ruby__QuoteTrigger on this object.
 *
 *            GAP-03 adds delete entry points. The handler captures related Opportunity IDs
 *            before deletion and recalculates them after deletion so primary Quote ARR does
 *            not remain on an Opportunity after its Quote is removed.
 */
trigger ELV_QuoteTrigger on Quote(
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete
) {
    new QuoteTriggerHandler().run();
}