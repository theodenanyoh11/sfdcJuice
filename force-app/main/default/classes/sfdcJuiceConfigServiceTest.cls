/**
 * @description Test class for sfdcJuiceConfigService
 */
@isTest
private class sfdcJuiceConfigServiceTest {

  @isTest
  static void testGetApiKeyAndBaseUrlAndValidateConfig() {
    // Build an in-memory config record (no DML required for these tests)
    sfdcJuice_Config__mdt config = new sfdcJuice_Config__mdt(
      DeveloperName = 'UnitTestConfig',
      MasterLabel = 'Unit Test Config',
      Helpjuice_API_Key__c = 'UNITTEST_KEY',
      Helpjuice_Base_URL__c = 'https://unittest.helpjuice.com',
      Is_Active__c = true,
      Max_Results_Per_Source__c = 10,
      Request_Timeout_Seconds__c = 20
    );

    // getApiKey should trim and return key
    String apiKey = sfdcJuiceConfigService.getApiKey(config);
    System.assertEquals('UNITTEST_KEY', apiKey);

    // getBaseUrl should return base URL when no Named Credential is set
    String baseUrl = sfdcJuiceConfigService.getBaseUrl(config);
    System.assertEquals('https://unittest.helpjuice.com', baseUrl);

    // validateConfig should succeed for this config
    System.assertEquals(true, sfdcJuiceConfigService.validateConfig(config));
  }

  @isTest
  static void testValidateConfigInvalidCases() {
    // Null config
    System.assertEquals(false, sfdcJuiceConfigService.validateConfig(null));

    // Missing API key
    sfdcJuice_Config__mdt noKeyConfig = new sfdcJuice_Config__mdt(
      DeveloperName = 'NoKeyConfig',
      MasterLabel = 'No Key Config',
      Helpjuice_Base_URL__c = 'https://unittest.helpjuice.com',
      Is_Active__c = true
    );
    System.assertEquals(false, sfdcJuiceConfigService.validateConfig(noKeyConfig));

    // Named Credential configured but no API key
    sfdcJuice_Config__mdt namedCredConfig = new sfdcJuice_Config__mdt(
      DeveloperName = 'NamedCredConfig',
      MasterLabel = 'Named Credential Config',
      Named_Credential_Name__c = 'Helpjuice_API',
      Is_Active__c = true
    );
    System.assertEquals(false, sfdcJuiceConfigService.validateConfig(namedCredConfig));
  }

  @isTest
  static void testGetBaseUrlWithNamedCredential() {
    sfdcJuice_Config__mdt namedCredConfig = new sfdcJuice_Config__mdt(
      DeveloperName = 'NamedCredConfig2',
      MasterLabel = 'Named Credential Config 2',
      Named_Credential_Name__c = 'Helpjuice_API',
      Helpjuice_API_Key__c = 'UNITTEST_KEY',
      Is_Active__c = true
    );

    String baseUrl = sfdcJuiceConfigService.getBaseUrl(namedCredConfig);
    System.assertEquals('callout:Helpjuice_API', baseUrl);
  }
}


