public class MetadataTypes {
    public class ReportType {
        public String fullName;
        public String baseObject;
        public String category;
        public String description;
        public String label;
        public String deployed;
        public List<ReportTypeSection> sections;
        public ObjectRelationShip joinRelationship;
        public String joinObjectsJSON;
        public Integer totalJoins;
        
        public ReportType() {
            sections = new List<ReportTypeSection>();
        }
    }
    
    public class ReportTypeSection {
        public String masterLabel;
        public List<ReportTypeSectionField> columns;
        
        public ReportTypeSection() {
            columns = new List<ReportTypeSectionField>();
        }
    }
    
    public class ReportTypeSectionField {
        public String field;
        public String table;
        public Boolean checkedByDefault;
    }
    
    public class ObjectRelationShip {
        public Boolean outerJoin;
        public String relationship;
        //public String relationshipObjectAPIName;
        public ObjectRelationShip joinRelationship;
    }
}