/**
 * @description Service for retrieving and managing sfdcJuice configuration from Custom Metadata
 * @author sfdcJuice
 */
public class sfdcJuiceConfigService {
  private static final String DEFAULT_CONFIG_DEV_NAME = 'Default';

  /**
   * @description Retrieves the active configuration record
   * @return sfdcJuice_Config__mdt The active configuration, or null if not found
   */
  public static sfdcJuice_Config__mdt getActiveConfig() {
    try {
      List<sfdcJuice_Config__mdt> configs = [
        SELECT
          Id,
          DeveloperName,
          Helpjuice_API_Key__c,
          Helpjuice_Base_URL__c,
          Named_Credential_Name__c,
          Is_Active__c,
          Max_Results_Per_Source__c,
          Request_Timeout_Seconds__c
        FROM sfdcJuice_Config__mdt
        WHERE Is_Active__c = TRUE
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];

      if (configs.isEmpty()) {
        // Try to get default config
        configs = [
          SELECT
            Id,
            DeveloperName,
            Helpjuice_API_Key__c,
            Helpjuice_Base_URL__c,
            Named_Credential_Name__c,
            Is_Active__c,
            Max_Results_Per_Source__c,
            Request_Timeout_Seconds__c
          FROM sfdcJuice_Config__mdt
          WHERE DeveloperName = :DEFAULT_CONFIG_DEV_NAME
          WITH SECURITY_ENFORCED
          LIMIT 1
        ];
      }

      return configs.isEmpty() ? null : configs[0];
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error retrieving sfdcJuice config: ' + e.getMessage()
      );
      return null;
    }
  }

  /**
   * @description Retrieves the API key securely from Named Credential or Custom Metadata
   * @param config The configuration record
   * @return String The API key, or null if not found
   */
  public static String getApiKey(sfdcJuice_Config__mdt config) {
    if (config == null) {
      return null;
    }

    // First, try to get API key from Named Credential if configured
    if (String.isNotBlank(config.Named_Credential_Name__c)) {
      try {
        // Named Credential stores the API key in its identity
        // We'll use the Named Credential endpoint and get the API key from the identity
        // Note: The API key should be configured in the Named Credential's Identity section
        // as a custom header named "Authorization"
        String namedCredentialName = config.Named_Credential_Name__c.trim();
        
        // Try to get the API key from Named Credential identity
        // Since Named Credentials don't expose identity directly in Apex,
        // we'll need to use a callout to retrieve it, or fall back to Custom Metadata
        // For now, we'll check if there's a way to get it, otherwise fall back
        
        // Note: In practice, the API key in Named Credential identity is not directly accessible
        // via Apex. The Named Credential will automatically add it to headers when making callouts.
        // So we'll use the Named Credential for the endpoint, but still need the API key
        // for manual header setting. We'll fall back to Custom Metadata.
      } catch (Exception e) {
        System.debug(
          LoggingLevel.WARN,
          'Error retrieving API key from Named Credential: ' + e.getMessage()
        );
      }
    }

    // Fall back to Custom Metadata field (should be encrypted with Platform Encryption)
    if (String.isNotBlank(config.Helpjuice_API_Key__c)) {
      return config.Helpjuice_API_Key__c.trim();
    }

    return null;
  }

  /**
   * @description Gets the base URL from Named Credential or Custom Metadata
   * @param config The configuration record
   * @return String The base URL, or null if not found
   */
  public static String getBaseUrl(sfdcJuice_Config__mdt config) {
    if (config == null) {
      return null;
    }

    // If Named Credential is configured, use it for the endpoint
    if (String.isNotBlank(config.Named_Credential_Name__c)) {
      String namedCredentialName = config.Named_Credential_Name__c.trim();
      // Return the Named Credential endpoint reference
      // The actual endpoint URL is configured in the Named Credential
      return 'callout:' + namedCredentialName;
    }

    // Fall back to Custom Metadata
    if (String.isNotBlank(config.Helpjuice_Base_URL__c)) {
      return config.Helpjuice_Base_URL__c.trim();
    }

    return null;
  }

  /**
   * @description Validates that the configuration is complete and valid
   * @param config The configuration to validate
   * @return Boolean True if valid, false otherwise
   */
  public static Boolean validateConfig(sfdcJuice_Config__mdt config) {
    if (config == null) {
      return false;
    }

    // Check if Named Credential is configured
    if (String.isNotBlank(config.Named_Credential_Name__c)) {
      // If Named Credential is used, API key should be in Named Credential identity
      // We still need the API key for manual header setting, so check Custom Metadata
      String apiKey = getApiKey(config);
      if (String.isBlank(apiKey)) {
        return false;
      }
      
      // Base URL comes from Named Credential, so we don't need to validate it here
      return true;
    }

    // Fallback: Validate Custom Metadata fields
    String apiKey = getApiKey(config);
    if (String.isBlank(apiKey)) {
      return false;
    }

    String baseUrl = getBaseUrl(config);
    if (String.isBlank(baseUrl)) {
      return false;
    }

    // Validate URL format (only if not using Named Credential)
    if (!baseUrl.startsWith('callout:')) {
      try {
        if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
          return false;
        }
      } catch (Exception e) {
        return false;
      }
    }

    return true;
  }
}

