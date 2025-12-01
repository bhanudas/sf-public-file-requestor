/**
 * @description Service class for Document Request configuration management
 * Handles retrieval and validation of configuration metadata
 * Supports mocking for tests via setMockConfig method
 */
public with sharing class DocumentRequestConfigService {
    
    private static Map<String, Document_Request_Config__mdt> configCache = new Map<String, Document_Request_Config__mdt>();
    
    // Mock support for testing
    @TestVisible
    private static Map<String, Document_Request_Config__mdt> mockConfigs = new Map<String, Document_Request_Config__mdt>();
    @TestVisible
    private static Boolean useMocks = false;
    
    // Default values when not configured
    public static final Integer DEFAULT_EXPIRATION_DAYS = 7;
    public static final Integer DEFAULT_MAX_FILE_SIZE_MB = 5;
    public static final Integer DEFAULT_MAX_FILES_PER_UPLOAD = 10;
    public static final String DEFAULT_ALLOWED_EXTENSIONS = 'pdf,jpg,jpeg,png,doc,docx,xls,xlsx';
    
    /**
     * @description Sets a mock configuration for testing
     * @param objectApiName The object API name to mock
     * @param config The mock configuration
     */
    @TestVisible
    private static void setMockConfig(String objectApiName, Document_Request_Config__mdt config) {
        mockConfigs.put(objectApiName, config);
        useMocks = true;
    }
    
    /**
     * @description Clears all mock configurations
     */
    @TestVisible
    private static void clearMocks() {
        mockConfigs.clear();
        useMocks = false;
    }
    
    /**
     * @description Creates a mock configuration record for testing
     */
    @TestVisible
    private static Document_Request_Config__mdt createMockConfig(
        String developerName,
        String objectApiName,
        String emailFieldPath,
        String nameFieldPath,
        String contactFieldPath
    ) {
        Document_Request_Config__mdt config = new Document_Request_Config__mdt(
            DeveloperName = developerName,
            MasterLabel = developerName,
            Source_Object_API_Name__c = objectApiName,
            Is_Active__c = true,
            Recipient_Email_Field_Path__c = emailFieldPath,
            Recipient_Name_Field_Path__c = nameFieldPath,
            Recipient_Contact_Field_Path__c = contactFieldPath,
            Default_Expiration_Days__c = 7,
            Max_File_Size_MB__c = 5,
            Max_Files_Per_Upload__c = 10,
            Allowed_File_Extensions__c = 'pdf,jpg,jpeg,png,doc,docx'
        );
        return config;
    }
    
    /**
     * @description Retrieves configuration for a specific object
     * @param objectApiName API name of the source object
     * @return Configuration record or null if not configured
     */
    public static Document_Request_Config__mdt getConfigForObject(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return null;
        }
        
        // Check mocks first (for testing)
        if (useMocks && mockConfigs.containsKey(objectApiName)) {
            return mockConfigs.get(objectApiName);
        }
        
        if (configCache.containsKey(objectApiName)) {
            return configCache.get(objectApiName);
        }
        
        List<Document_Request_Config__mdt> configs = [
            SELECT Id, DeveloperName, MasterLabel, Source_Object_API_Name__c,
                   Is_Active__c, Recipient_Email_Field_Path__c, Recipient_Name_Field_Path__c,
                   Recipient_Contact_Field_Path__c, Default_Expiration_Days__c,
                   Max_File_Size_MB__c, Max_Files_Per_Upload__c, Allowed_File_Extensions__c,
                   Quick_Action_Label__c, Email_Template_Name__c
            FROM Document_Request_Config__mdt
            WHERE Source_Object_API_Name__c = :objectApiName
              AND Is_Active__c = true
            LIMIT 1
        ];
        
        Document_Request_Config__mdt config = configs.isEmpty() ? null : configs[0];
        configCache.put(objectApiName, config);
        return config;
    }
    
    /**
     * @description Retrieves configuration by developer name
     * @param developerName Developer name of the configuration
     * @return Configuration record or null if not found
     */
    public static Document_Request_Config__mdt getConfigByDeveloperName(String developerName) {
        if (String.isBlank(developerName)) {
            return null;
        }
        
        List<Document_Request_Config__mdt> configs = [
            SELECT Id, DeveloperName, MasterLabel, Source_Object_API_Name__c,
                   Is_Active__c, Recipient_Email_Field_Path__c, Recipient_Name_Field_Path__c,
                   Recipient_Contact_Field_Path__c, Default_Expiration_Days__c,
                   Max_File_Size_MB__c, Max_Files_Per_Upload__c, Allowed_File_Extensions__c,
                   Quick_Action_Label__c, Email_Template_Name__c
            FROM Document_Request_Config__mdt
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        
        return configs.isEmpty() ? null : configs[0];
    }
    
    /**
     * @description Retrieves recipient information from a source record
     * @param recordId Source record ID
     * @param config Configuration record
     * @return Wrapper containing recipient name, email, and optional Contact Id
     */
    public static RecipientInfo getRecipientInfo(Id recordId, Document_Request_Config__mdt config) {
        if (recordId == null || config == null) {
            return new RecipientInfo();
        }
        
        String objectApiName = config.Source_Object_API_Name__c;
        Set<String> fieldsToQuery = new Set<String>{'Id'};
        
        // Parse field paths
        String emailPath = config.Recipient_Email_Field_Path__c;
        String namePath = config.Recipient_Name_Field_Path__c;
        String contactPath = config.Recipient_Contact_Field_Path__c;
        
        if (String.isNotBlank(emailPath)) {
            fieldsToQuery.add(emailPath);
        }
        if (String.isNotBlank(namePath)) {
            fieldsToQuery.add(namePath);
        }
        if (String.isNotBlank(contactPath)) {
            fieldsToQuery.add(contactPath);
        }
        
        // Build and execute query
        String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + 
                       ' FROM ' + String.escapeSingleQuotes(objectApiName) + 
                       ' WHERE Id = :recordId LIMIT 1';
        
        List<SObject> records = Database.query(query);
        if (records.isEmpty()) {
            return new RecipientInfo();
        }
        
        SObject record = records[0];
        RecipientInfo info = new RecipientInfo();
        
        info.email = (String) getFieldValue(record, emailPath);
        info.name = (String) getFieldValue(record, namePath);
        
        if (String.isNotBlank(contactPath)) {
            Object contactIdValue = getFieldValue(record, contactPath);
            if (contactIdValue != null) {
                info.contactId = (Id) contactIdValue;
            }
        }
        
        return info;
    }
    
    /**
     * @description Traverses a field path and returns the value
     * @param record Source record
     * @param fieldPath Dot-notation field path
     * @return Field value or null
     */
    public static Object getFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) {
            return null;
        }
        
        List<String> pathParts = fieldPath.split('\\.');
        SObject current = record;
        
        for (Integer i = 0; i < pathParts.size(); i++) {
            String part = pathParts[i];
            
            if (i == pathParts.size() - 1) {
                // Last part - get the field value
                return current.get(part);
            } else {
                // Intermediate part - traverse relationship
                current = current.getSObject(part);
                if (current == null) {
                    return null;
                }
            }
        }
        
        return null;
    }
    
    /**
     * @description Validates a configuration record
     * @param config Configuration to validate
     * @return List of validation error messages (empty if valid)
     */
    public static List<String> validateConfig(Document_Request_Config__mdt config) {
        List<String> errors = new List<String>();
        
        if (config == null) {
            errors.add('Configuration record is null');
            return errors;
        }
        
        // Validate Source Object exists
        if (String.isBlank(config.Source_Object_API_Name__c)) {
            errors.add('Source Object API Name is required');
        } else {
            try {
                Schema.getGlobalDescribe().get(config.Source_Object_API_Name__c);
            } catch (Exception e) {
                errors.add('Invalid Source Object API Name: ' + config.Source_Object_API_Name__c);
            }
        }
        
        // Validate Email Field Path
        if (String.isBlank(config.Recipient_Email_Field_Path__c)) {
            errors.add('Recipient Email Field Path is required');
        }
        
        return errors;
    }
    
    /**
     * @description Gets expiration days from config or returns default
     */
    public static Integer getExpirationDays(Document_Request_Config__mdt config) {
        if (config?.Default_Expiration_Days__c != null) {
            return (Integer) config.Default_Expiration_Days__c;
        }
        return DEFAULT_EXPIRATION_DAYS;
    }
    
    /**
     * @description Gets max file size from config or returns default
     */
    public static Integer getMaxFileSizeMB(Document_Request_Config__mdt config) {
        if (config?.Max_File_Size_MB__c != null) {
            return (Integer) config.Max_File_Size_MB__c;
        }
        return DEFAULT_MAX_FILE_SIZE_MB;
    }
    
    /**
     * @description Gets max files per upload from config or returns default
     */
    public static Integer getMaxFilesPerUpload(Document_Request_Config__mdt config) {
        if (config?.Max_Files_Per_Upload__c != null) {
            return (Integer) config.Max_Files_Per_Upload__c;
        }
        return DEFAULT_MAX_FILES_PER_UPLOAD;
    }
    
    /**
     * @description Gets allowed extensions from config or returns default
     */
    public static List<String> getAllowedExtensions(Document_Request_Config__mdt config) {
        String extensionsStr = config?.Allowed_File_Extensions__c;
        if (String.isBlank(extensionsStr)) {
            extensionsStr = DEFAULT_ALLOWED_EXTENSIONS;
        }
        
        List<String> extensions = new List<String>();
        for (String ext : extensionsStr.split(',')) {
            extensions.add(ext.trim().toLowerCase());
        }
        return extensions;
    }
    
    /**
     * @description Clears the configuration cache (useful for testing)
     */
    @TestVisible
    private static void clearCache() {
        configCache.clear();
    }
    
    /**
     * @description Wrapper class for recipient information
     */
    public class RecipientInfo {
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        
        public RecipientInfo() {
            this.email = null;
            this.name = null;
            this.contactId = null;
        }
    }
}

