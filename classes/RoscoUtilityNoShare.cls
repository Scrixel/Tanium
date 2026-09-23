public without sharing class RoscoUtilityNoShare {


    /** createAttachment
     * @param Attachment
     * @return String attachment Id
     */
    public static String createAttachment(Attachment newAttachment) {    

        insert newAttachment;
        return String.valueOf(newAttachment.Id);

    }


}