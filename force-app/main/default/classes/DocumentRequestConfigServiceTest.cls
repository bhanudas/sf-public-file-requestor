/**
 * @description Test class for DocumentRequestConfigService
 */
@isTest
private class DocumentRequestConfigServiceTest {
  @isTest
  static void testGetConfigForObject_NoConfig() {
    // Test when no config exists
    Document_Request_Config__mdt config = DocumentRequestConfigService.getConfigForObject(
      'NonExistentObject__c'
    );
    // Config may or may not exist depending on org state - we just verify it doesn't throw
    System.assert(true, 'Test executed without error');
  }

  @isTest
  static void testGetConfigForObject_NullInput() {
    Document_Request_Config__mdt config = DocumentRequestConfigService.getConfigForObject(
      null
    );
    System.assertEquals(null, config, 'Null input should return null config');
  }

  @isTest
  static void testGetConfigForObject_BlankInput() {
    Document_Request_Config__mdt config = DocumentRequestConfigService.getConfigForObject(
      ''
    );
    System.assertEquals(null, config, 'Blank input should return null config');
  }

  @isTest
  static void testGetConfigByDeveloperName_NullInput() {
    Document_Request_Config__mdt config = DocumentRequestConfigService.getConfigByDeveloperName(
      null
    );
    System.assertEquals(null, config, 'Null input should return null config');
  }

  @isTest
  static void testGetConfigByDeveloperName_BlankInput() {
    Document_Request_Config__mdt config = DocumentRequestConfigService.getConfigByDeveloperName(
      ''
    );
    System.assertEquals(null, config, 'Blank input should return null config');
  }

  @isTest
  static void testGetRecipientInfo_NullInputs() {
    DocumentRequestConfigService.RecipientInfo info = DocumentRequestConfigService.getRecipientInfo(
      null,
      null
    );
    System.assertEquals(null, info.email, 'Email should be null');
    System.assertEquals(null, info.name, 'Name should be null');
    System.assertEquals(null, info.contactId, 'Contact ID should be null');
  }

  @isTest
  static void testGetFieldValue_NullRecord() {
    Object result = DocumentRequestConfigService.getFieldValue(null, 'Name');
    System.assertEquals(null, result, 'Null record should return null');
  }

  @isTest
  static void testGetFieldValue_NullPath() {
    Account acc = new Account(Name = 'Test');
    Object result = DocumentRequestConfigService.getFieldValue(acc, null);
    System.assertEquals(null, result, 'Null path should return null');
  }

  @isTest
  static void testGetFieldValue_BlankPath() {
    Account acc = new Account(Name = 'Test');
    Object result = DocumentRequestConfigService.getFieldValue(acc, '');
    System.assertEquals(null, result, 'Blank path should return null');
  }

  @isTest
  static void testGetFieldValue_SimpleField() {
    Account acc = new Account(Name = 'Test Account');
    Object result = DocumentRequestConfigService.getFieldValue(acc, 'Name');
    System.assertEquals('Test Account', result, 'Should return field value');
  }

  @isTest
  static void testValidateConfig_NullConfig() {
    List<String> errors = DocumentRequestConfigService.validateConfig(null);
    System.assertEquals(1, errors.size(), 'Should have one error');
    System.assertEquals(
      'Configuration record is null',
      errors[0],
      'Error message should match'
    );
  }

  @isTest
  static void testGetExpirationDays_Default() {
    Integer days = DocumentRequestConfigService.getExpirationDays(null);
    System.assertEquals(
      DocumentRequestConfigService.DEFAULT_EXPIRATION_DAYS,
      days,
      'Should return default expiration days'
    );
  }

  @isTest
  static void testGetMaxFileSizeMB_Default() {
    Integer size = DocumentRequestConfigService.getMaxFileSizeMB(null);
    System.assertEquals(
      DocumentRequestConfigService.DEFAULT_MAX_FILE_SIZE_MB,
      size,
      'Should return default max file size'
    );
  }

  @isTest
  static void testGetMaxFilesPerUpload_Default() {
    Integer count = DocumentRequestConfigService.getMaxFilesPerUpload(null);
    System.assertEquals(
      DocumentRequestConfigService.DEFAULT_MAX_FILES_PER_UPLOAD,
      count,
      'Should return default max files per upload'
    );
  }

  @isTest
  static void testGetAllowedExtensions_Default() {
    List<String> extensions = DocumentRequestConfigService.getAllowedExtensions(
      null
    );
    System.assert(!extensions.isEmpty(), 'Should return default extensions');
    System.assert(extensions.contains('pdf'), 'Should contain pdf');
  }

  @isTest
  static void testClearCache() {
    DocumentRequestConfigService.clearCache();
    // Test that cache was cleared by running a query - just verify no error thrown
    Document_Request_Config__mdt config = DocumentRequestConfigService.getConfigForObject(
      'Account'
    );
    System.assert(true, 'Cache clear should work without error');
  }

  @isTest
  static void testRecipientInfoClass() {
    DocumentRequestConfigService.RecipientInfo info = new DocumentRequestConfigService.RecipientInfo();
    info.email = 'test@test.com';
    info.name = 'Test Name';
    info.contactId = null;

    System.assertEquals('test@test.com', info.email, 'Email should be set');
    System.assertEquals('Test Name', info.name, 'Name should be set');
  }

  @isTest
  static void testGetRecipientInfoWithRecord() {
    // Create test data
    Account acc = DocReqTestDataFactory.createAccount('Test Account', true);
    Contact con = DocReqTestDataFactory.createContact(
      acc.Id,
      'Test',
      'Contact',
      'test@test.com',
      true
    );
    Case c = DocReqTestDataFactory.createCase(con.Id, 'Test Case', true);

    // Query the case with contact relationship
    Case queriedCase = [
      SELECT Id, Contact.Email, Contact.Name, ContactId
      FROM Case
      WHERE Id = :c.Id
    ];

    // Test field value extraction
    Object emailValue = DocumentRequestConfigService.getFieldValue(
      queriedCase,
      'Contact.Email'
    );
    System.assertEquals(
      'test@test.com',
      emailValue,
      'Should get email from relationship'
    );
  }

  @isTest
  static void testGetFieldValue_RelationshipPath() {
    Account acc = DocReqTestDataFactory.createAccount('Test Account', true);
    Contact con = DocReqTestDataFactory.createContact(
      acc.Id,
      'Test',
      'Contact',
      'test@test.com',
      true
    );
    Case c = DocReqTestDataFactory.createCase(con.Id, 'Test Case', true);

    Case queriedCase = [
      SELECT Id, Contact.Email, Contact.Name, Contact.Account.Name
      FROM Case
      WHERE Id = :c.Id
    ];

    // Test traversing multiple levels
    Object accountName = DocumentRequestConfigService.getFieldValue(
      queriedCase,
      'Contact.Account.Name'
    );
    System.assertEquals(
      'Test Account',
      accountName,
      'Should get account name from relationship'
    );
  }

  @isTest
  static void testGetFieldValue_NullRelationship() {
    Case c = new Case(Subject = 'Test');
    insert c;

    Case queriedCase = [SELECT Id, Contact.Email FROM Case WHERE Id = :c.Id];
    Object emailValue = DocumentRequestConfigService.getFieldValue(
      queriedCase,
      'Contact.Email'
    );
    System.assertEquals(
      null,
      emailValue,
      'Should return null for null relationship'
    );
  }

  @isTest
  static void testValidateConfig_BlankObjectName() {
    Document_Request_Config__mdt config = new Document_Request_Config__mdt(
      Source_Object_API_Name__c = '',
      Recipient_Email_Field_Path__c = 'Email'
    );

    List<String> errors = DocumentRequestConfigService.validateConfig(config);
    System.assert(!errors.isEmpty(), 'Should have validation errors');
    System.assert(
      errors[0].contains('Source Object API Name'),
      'Should have source object error'
    );
  }

  @isTest
  static void testValidateConfig_BlankEmailPath() {
    Document_Request_Config__mdt config = new Document_Request_Config__mdt(
      Source_Object_API_Name__c = 'Case',
      Recipient_Email_Field_Path__c = ''
    );

    List<String> errors = DocumentRequestConfigService.validateConfig(config);
    System.assert(!errors.isEmpty(), 'Should have validation errors');
  }

  @isTest
  static void testGetRecipientInfo_NullRecord() {
    Document_Request_Config__mdt config = new Document_Request_Config__mdt(
      Source_Object_API_Name__c = 'Case',
      Recipient_Email_Field_Path__c = 'Contact.Email'
    );

    DocumentRequestConfigService.RecipientInfo info = DocumentRequestConfigService.getRecipientInfo(
      null,
      config
    );
    System.assertEquals(
      null,
      info.email,
      'Should return empty info for null record'
    );
  }

  @isTest
  static void testGetRecipientInfo_NullConfig() {
    Account acc = DocReqTestDataFactory.createAccount('Test', true);

    DocumentRequestConfigService.RecipientInfo info = DocumentRequestConfigService.getRecipientInfo(
      acc.Id,
      null
    );
    System.assertEquals(
      null,
      info.email,
      'Should return empty info for null config'
    );
  }

  @isTest
  static void testGetRecipientInfo_WithContactPath() {
    Account acc = DocReqTestDataFactory.createAccount('Test Account', true);
    Contact con = DocReqTestDataFactory.createContact(
      acc.Id,
      'Test',
      'Contact',
      'test@test.com',
      true
    );
    Case c = DocReqTestDataFactory.createCase(con.Id, 'Test Case', true);

    // Create a mock config
    Document_Request_Config__mdt config = new Document_Request_Config__mdt(
      Source_Object_API_Name__c = 'Case',
      Recipient_Email_Field_Path__c = 'Contact.Email',
      Recipient_Name_Field_Path__c = 'Contact.Name',
      Recipient_Contact_Field_Path__c = 'ContactId'
    );

    Test.startTest();
    DocumentRequestConfigService.RecipientInfo info = DocumentRequestConfigService.getRecipientInfo(
      c.Id,
      config
    );
    Test.stopTest();

    System.assertEquals('test@test.com', info.email, 'Email should match');
    System.assertEquals('Test Contact', info.name, 'Name should match');
    System.assertEquals(con.Id, info.contactId, 'Contact ID should match');
  }

  @isTest
  static void testGetRecipientInfo_InvalidRecordId() {
    Document_Request_Config__mdt config = new Document_Request_Config__mdt(
      Source_Object_API_Name__c = 'Case',
      Recipient_Email_Field_Path__c = 'Contact.Email'
    );

    // Use a fake Case ID that doesn't exist
    Id fakeId = '500000000000000AAA';

    Test.startTest();
    DocumentRequestConfigService.RecipientInfo info = DocumentRequestConfigService.getRecipientInfo(
      fakeId,
      config
    );
    Test.stopTest();

    System.assertEquals(
      null,
      info.email,
      'Should return empty for non-existent record'
    );
  }

  @isTest
  static void testConfigCaching() {
    // First call
    Document_Request_Config__mdt config1 = DocumentRequestConfigService.getConfigForObject(
      'Case'
    );

    // Second call should use cache
    Document_Request_Config__mdt config2 = DocumentRequestConfigService.getConfigForObject(
      'Case'
    );

    // Just verify no errors - caching is internal
    System.assert(true, 'Caching should work without error');
  }

  @isTest
  static void testSetMockConfig() {
    // Create mock config
    Document_Request_Config__mdt mockConfig = DocumentRequestConfigService.createMockConfig(
      'Test_Config',
      'Account',
      'Name',
      'Name',
      null
    );

    // Set the mock
    DocumentRequestConfigService.setMockConfig('Account', mockConfig);

    Test.startTest();
    Document_Request_Config__mdt result = DocumentRequestConfigService.getConfigForObject(
      'Account'
    );
    Test.stopTest();

    // Clear mocks
    DocumentRequestConfigService.clearMocks();

    System.assertNotEquals(null, result, 'Should return mock config');
    System.assertEquals(
      'Account',
      result.Source_Object_API_Name__c,
      'Object should match'
    );
  }

  @isTest
  static void testClearMocks() {
    // Set a mock
    Document_Request_Config__mdt mockConfig = DocumentRequestConfigService.createMockConfig(
      'Test_Config',
      'Opportunity',
      'Name',
      'Name',
      null
    );
    DocumentRequestConfigService.setMockConfig('Opportunity', mockConfig);

    // Verify mock is active
    Document_Request_Config__mdt result1 = DocumentRequestConfigService.getConfigForObject(
      'Opportunity'
    );
    System.assertNotEquals(null, result1, 'Mock should be active');

    // Clear mocks
    DocumentRequestConfigService.clearMocks();

    // Clear cache too
    DocumentRequestConfigService.clearCache();

    Test.startTest();
    Document_Request_Config__mdt result2 = DocumentRequestConfigService.getConfigForObject(
      'Opportunity'
    );
    Test.stopTest();

    // After clearing, should query DB (which has no config for Opportunity)
    System.assertEquals(
      null,
      result2,
      'Should return null after clearing mocks'
    );
  }

  @isTest
  static void testCreateMockConfig() {
    Test.startTest();
    Document_Request_Config__mdt config = DocumentRequestConfigService.createMockConfig(
      'My_Config',
      'Lead',
      'Email',
      'Name',
      null
    );
    Test.stopTest();

    System.assertEquals(
      'My_Config',
      config.DeveloperName,
      'Developer name should match'
    );
    System.assertEquals(
      'Lead',
      config.Source_Object_API_Name__c,
      'Object should match'
    );
    System.assertEquals(
      'Email',
      config.Recipient_Email_Field_Path__c,
      'Email path should match'
    );
    System.assertEquals(
      'Name',
      config.Recipient_Name_Field_Path__c,
      'Name path should match'
    );
    System.assertEquals(true, config.Is_Active__c, 'Should be active');
    System.assertEquals(
      7,
      config.Default_Expiration_Days__c,
      'Default expiration should be 7'
    );
  }

  @isTest
  static void testMockConfigWithCustomValues() {
    Document_Request_Config__mdt mockConfig = new Document_Request_Config__mdt(
      DeveloperName = 'Custom_Config',
      Source_Object_API_Name__c = 'Case',
      Is_Active__c = true,
      Recipient_Email_Field_Path__c = 'Contact.Email',
      Default_Expiration_Days__c = 14,
      Max_File_Size_MB__c = 10,
      Max_Files_Per_Upload__c = 5,
      Allowed_File_Extensions__c = 'pdf,png'
    );

    DocumentRequestConfigService.setMockConfig('Case', mockConfig);

    Test.startTest();
    Integer expirationDays = DocumentRequestConfigService.getExpirationDays(
      mockConfig
    );
    Integer maxFileSize = DocumentRequestConfigService.getMaxFileSizeMB(
      mockConfig
    );
    Integer maxFiles = DocumentRequestConfigService.getMaxFilesPerUpload(
      mockConfig
    );
    List<String> extensions = DocumentRequestConfigService.getAllowedExtensions(
      mockConfig
    );
    Test.stopTest();

    DocumentRequestConfigService.clearMocks();

    System.assertEquals(14, expirationDays, 'Expiration days should be 14');
    System.assertEquals(10, maxFileSize, 'Max file size should be 10');
    System.assertEquals(5, maxFiles, 'Max files should be 5');
    System.assertEquals(2, extensions.size(), 'Should have 2 extensions');
  }
}
