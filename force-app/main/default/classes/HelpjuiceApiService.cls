/**
 * @description Service for interacting with Helpjuice API v3
 * @author sfdcJuice
 * @see https://help.helpjuice.com/en_US/api-v3/using-api-v3
 */
public class HelpjuiceApiService {
  private static final String API_VERSION = 'v3';
  private static final String SEARCH_ENDPOINT = '/api/v3/search';
  private static final String ARTICLES_ENDPOINT = '/api/v3/articles';
  private static final String CATEGORIES_ENDPOINT = '/api/v3/categories';

  /**
   * @description Searches Helpjuice articles using the API v3 search endpoint
   * @param searchQuery The search query string
   * @param maxResults Maximum number of results to return
   * @param pageNumber Page number for pagination
   * @return List<UnifiedArticle> List of unified articles from Helpjuice
   */
  public static List<UnifiedArticle> searchArticles(
    String searchQuery,
    Integer maxResults,
    Integer pageNumber
  ) {
    List<UnifiedArticle> articles = new List<UnifiedArticle>();

    // Validate search query - Helpjuice API requires minimum 3 characters
    if (String.isBlank(searchQuery)) {
      System.debug(
        LoggingLevel.WARN,
        'HelpjuiceApiService: Query is empty'
      );
      // Return empty list for empty queries instead of throwing error
      return articles;
    }

    // Trim and normalize the search query
    searchQuery = searchQuery.trim();
    
    // Check minimum length - Helpjuice typically requires at least 3 characters
    if (searchQuery.length() < 3) {
      System.debug(
        LoggingLevel.WARN,
        'HelpjuiceApiService: Query too short (minimum 3 characters): "' + searchQuery + '"'
      );
      // Return empty list for queries that are too short
      return articles;
    }

    sfdcJuice_Config__mdt config = sfdcJuiceConfigService.getActiveConfig();
    if (config == null) {
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: No configuration found'
      );
      String errorMsg = 'Helpjuice configuration not found. Please configure Custom Metadata at Setup > Custom Metadata Types > sfdcJuice Config > Manage Records > Default.';
      throw new AuraHandledException(errorMsg);
    }
    
    // Check if configuration has placeholder values
    String apiKey = sfdcJuiceConfigService.getApiKey(config);
    String baseUrl = sfdcJuiceConfigService.getBaseUrl(config);
    
    if (String.isBlank(apiKey) || 
        apiKey.equals('YOUR_API_KEY_HERE') ||
        String.isBlank(baseUrl) ||
        (!baseUrl.startsWith('callout:') && baseUrl.contains('youraccount'))) {
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: Configuration has placeholder values - API Key: ' +
        (String.isNotBlank(apiKey) ? 'Present' : 'Missing') +
        ', Base URL: ' +
        baseUrl
      );
      String errorMsg = 'Helpjuice configuration is not set up. Please update the "Default" Custom Metadata record with your actual Helpjuice API Key and Base URL (or configure a Named Credential). Current values appear to be placeholders.';
      throw new AuraHandledException(errorMsg);
    }
    
    if (!sfdcJuiceConfigService.validateConfig(config)) {
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: Invalid or missing configuration - API Key: ' +
        (String.isNotBlank(sfdcJuiceConfigService.getApiKey(config)) ? 'Present' : 'Missing') +
        ', Base URL: ' +
        sfdcJuiceConfigService.getBaseUrl(config)
      );
      String errorMsg = 'Invalid Helpjuice configuration. Please check that API Key and Base URL are properly configured in Custom Metadata. Base URL must start with https://';
      throw new AuraHandledException(errorMsg);
    }

    try {
      // Reuse baseUrl and apiKey from validation above (already declared at lines 60-61)
      if (String.isBlank(baseUrl)) {
        throw new AuraHandledException('Helpjuice Base URL is not configured. Please configure either a Named Credential or Base URL in Custom Metadata.');
      }

      if (String.isBlank(apiKey)) {
        throw new AuraHandledException('Helpjuice API Key is not configured. Please configure the API key in Custom Metadata (with Platform Encryption enabled for security).');
      }

      // Handle Named Credential endpoint vs regular URL
      String endpoint;
      String actualBaseUrl = baseUrl; // Keep original for URL construction
      if (baseUrl.startsWith('callout:')) {
        // Named Credential endpoint - append the API path
        endpoint = baseUrl + SEARCH_ENDPOINT;
      } else {
        // Regular URL - trim and append
        actualBaseUrl = baseUrl.trim();
        if (actualBaseUrl.endsWith('/')) {
          actualBaseUrl = actualBaseUrl.removeEnd('/');
        }
        endpoint = actualBaseUrl + SEARCH_ENDPOINT;
      }

      Integer timeout = config.Request_Timeout_Seconds__c != null 
        ? (Integer) config.Request_Timeout_Seconds__c 
        : 30;

      // Build query parameters - Helpjuice API v3 uses 'query' parameter (not 'q')
      // See: https://help.helpjuice.com/en_US/api-v3/using-api-v3
      Map<String, String> queryParams = new Map<String, String>();
      queryParams.put('query', EncodingUtil.urlEncode(searchQuery, 'UTF-8'));
      // Note: Helpjuice API v3 search endpoint doesn't use 'limit' or 'page' parameters
      // Pagination is handled differently in the response
      // Note: Using Authorization header instead of query parameter for better security

      String queryString = '';
      for (String key : queryParams.keySet()) {
        if (String.isNotBlank(queryString)) {
          queryString += '&';
        }
        queryString += key + '=' + queryParams.get(key);
      }

      endpoint += '?' + queryString;

      String endpointForLog = endpoint;
      System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Calling endpoint: ' + endpointForLog);
      System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Base URL: ' + baseUrl);
      System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: API Key present: ' + (String.isNotBlank(apiKey) ? 'Yes (length: ' + apiKey.length() + ')' : 'No'));
      System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Using Named Credential: ' + (baseUrl.startsWith('callout:') ? 'Yes' : 'No'));

      HttpRequest req = new HttpRequest();
      req.setEndpoint(endpoint);
      req.setMethod('GET');
      // Use Authorization header for API key (more secure than query parameter)
      req.setHeader('Authorization', apiKey);
      req.setHeader('Accept', 'application/json');
      req.setHeader('Content-Type', 'application/json');
      req.setTimeout(timeout * 1000);

      Http http = new Http();
      HttpResponse res = http.send(req);

      System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Response Status: ' + res.getStatusCode());
      System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Response Body length: ' + res.getBody().length());
      if (res.getBody().length() > 0) {
        System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Response Body: ' + res.getBody().substring(0, Math.min(500, res.getBody().length())));
      }

      if (res.getStatusCode() == 200) {
        articles = parseSearchResponse(res.getBody());
        System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Parsed ' + articles.size() + ' articles');
      } else {
        String errorBody = res.getBody();
        System.debug(
          LoggingLevel.ERROR,
          'HelpjuiceApiService: API error ' +
          res.getStatusCode() +
          ' - ' +
          errorBody
        );
        
        // Parse error response to extract meaningful error messages
        String errorMessage = parseErrorResponse(res.getStatusCode(), errorBody, searchQuery);
        throw new AuraHandledException(errorMessage);
      }
    } catch (CalloutException e) {
      String errorMsg = e.getMessage();
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: Callout exception: ' + errorMsg
      );
      System.debug(LoggingLevel.ERROR, 'HelpjuiceApiService: Exception type: ' + e.getTypeName());
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
      
      // Check if it's a Remote Site Settings issue (only if not using Named Credential)
      if (errorMsg != null && errorMsg.contains('Remote site settings')) {
        String configBaseUrl = baseUrl;
        if (configBaseUrl.startsWith('callout:')) {
          // Using Named Credential - no Remote Site Settings needed
          String detailedMsg = 'Remote Site Settings issue: If you are using a Named Credential, Remote Site Settings are not required. Please verify your Named Credential is configured correctly. Current error: ' + errorMsg;
          throw new AuraHandledException(detailedMsg);
        } else {
          // Extract just the domain for Remote Site Settings
          try {
            if (configBaseUrl.startsWith('http://') || configBaseUrl.startsWith('https://')) {
              String domainOnly = configBaseUrl.replace('http://', '').replace('https://', '');
              if (domainOnly.contains('/')) {
                domainOnly = domainOnly.substring(0, domainOnly.indexOf('/'));
              }
              configBaseUrl = 'https://' + domainOnly;
            }
          } catch (Exception ex) {
            // Use full URL if parsing fails
          }
          String detailedMsg = 'Remote Site Settings issue: Please ensure "' + configBaseUrl + '" (or its base domain) is added to Remote Site Settings at Setup > Security > Remote Site Settings, or configure a Named Credential instead. Current error: ' + errorMsg;
          throw new AuraHandledException(detailedMsg);
        }
      }
      
      // Provide more detailed error message
      String detailedError = 'Failed to connect to Helpjuice API. ';
      if (config != null) {
        detailedError += 'Endpoint: ' + baseUrl + SEARCH_ENDPOINT + '. ';
      }
      detailedError += 'Error: ' + (errorMsg != null ? errorMsg : 'Unknown error');
      throw new AuraHandledException(detailedError);
    } catch (AuraHandledException e) {
      // Re-throw AuraHandledException as-is to preserve the message
      System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Re-throwing AuraHandledException: ' + e.getMessage());
      throw e;
    } catch (Exception e) {
      String errorMsg = e.getMessage();
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: Unexpected error: ' + errorMsg
      );
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
      throw new AuraHandledException(
        'Error calling Helpjuice API: ' + (errorMsg != null ? errorMsg : 'Unknown error occurred')
      );
    }

    return articles;
  }

  /**
   * @description Retrieves a specific article by ID from Helpjuice
   * @param articleId The Helpjuice article ID
   * @return UnifiedArticle The article, or null if not found
   */
  public static UnifiedArticle getArticleById(String articleId) {
    UnifiedArticle article = null;

    sfdcJuice_Config__mdt config = sfdcJuiceConfigService.getActiveConfig();
    if (config == null) {
      throw new AuraHandledException('Helpjuice configuration not found. Please configure sfdcJuice_Config__mdt Custom Metadata.');
    }
    if (!sfdcJuiceConfigService.validateConfig(config)) {
      throw new AuraHandledException('Helpjuice configuration is invalid. Please check your API key and Base URL in sfdcJuice_Config__mdt Custom Metadata.');
    }

    try {
      // Get base URL from Named Credential or Custom Metadata
      String baseUrl = sfdcJuiceConfigService.getBaseUrl(config);
      if (String.isBlank(baseUrl)) {
        throw new AuraHandledException('Helpjuice Base URL is not configured. Please configure either a Named Credential or Base URL in Custom Metadata.');
      }

      // Get API key securely
      String apiKey = sfdcJuiceConfigService.getApiKey(config);
      if (String.isBlank(apiKey)) {
        throw new AuraHandledException('Helpjuice API Key is not configured. Please configure the API key in Custom Metadata (with Platform Encryption enabled for security).');
      }

      // Handle Named Credential endpoint vs regular URL
      String endpoint;
      if (baseUrl.startsWith('callout:')) {
        // Named Credential endpoint - append the API path
        endpoint = baseUrl + ARTICLES_ENDPOINT + '/' + articleId;
      } else {
        // Regular URL - trim and append
        baseUrl = baseUrl.trim();
        if (baseUrl.endsWith('/')) {
          baseUrl = baseUrl.removeEnd('/');
        }
        endpoint = baseUrl + ARTICLES_ENDPOINT + '/' + articleId;
      }
      Integer timeout = config.Request_Timeout_Seconds__c != null 
        ? (Integer) config.Request_Timeout_Seconds__c 
        : 30;
      
      // Note: Using Authorization header instead of query parameter for better security
      // Helpjuice API v3 accepts API key in Authorization header OR as api_key query parameter

      HttpRequest req = new HttpRequest();
      req.setEndpoint(endpoint);
      req.setMethod('GET');
      // Use Authorization header for API key (more secure than query parameter)
      req.setHeader('Authorization', apiKey);
      req.setHeader('Accept', 'application/json');
      req.setHeader('Content-Type', 'application/json');
      req.setTimeout(timeout * 1000);

      Http http = new Http();
      HttpResponse res = http.send(req);

      if (res.getStatusCode() == 200) {
        String responseBody = res.getBody();
        System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Successfully retrieved article. Response length: ' + (responseBody != null ? responseBody.length() : 0));
        System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Response preview: ' + (responseBody != null ? responseBody.substring(0, Math.min(2000, responseBody.length())) : 'null'));
        article = parseArticleResponse(responseBody);
        if (article == null) {
          System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: parseArticleResponse returned null for article ID: ' + articleId);
          System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Response body: ' + (responseBody != null ? responseBody.substring(0, Math.min(1000, responseBody.length())) : 'null'));
          throw new AuraHandledException('Failed to parse article response from Helpjuice. Please check debug logs for details.');
        }
        // Log the article content status after parsing
        if (article != null) {
          System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Article parsed successfully. Title: ' + article.title);
          System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Article content length: ' + (article.content != null ? article.content.length() : 0));
          System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Article content preview: ' + (article.content != null && article.content.length() > 0 ? article.content.substring(0, Math.min(500, article.content.length())) : 'empty or null'));
        }
      } else {
        String errorMsg = parseErrorResponse(res.getStatusCode(), res.getBody(), articleId);
        System.debug(LoggingLevel.ERROR, 'HelpjuiceApiService: Failed to retrieve article. Status: ' + res.getStatusCode() + ', Error: ' + errorMsg);
        throw new AuraHandledException('Failed to retrieve article from Helpjuice (HTTP ' + res.getStatusCode() + '): ' + errorMsg);
      }
    } catch (AuraHandledException e) {
      // Re-throw AuraHandledException as-is
      System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Re-throwing AuraHandledException: ' + e.getMessage());
      throw e;
    } catch (Exception e) {
      String errorMsg = e.getMessage();
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: Error retrieving article: ' + errorMsg
      );
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
      throw new AuraHandledException(
        'Error retrieving article from Helpjuice: ' + (errorMsg != null ? errorMsg : 'Unknown error occurred')
      );
    }

    return article;
  }

  /**
   * @description Retrieves popular articles from Helpjuice (sorted by views)
   * @param maxResults Maximum number of articles to return
   * @return List<UnifiedArticle> List of popular articles
   */
  @AuraEnabled(cacheable=false)
  public static List<UnifiedArticle> getPopularArticles(Integer maxResults) {
    List<UnifiedArticle> articles = new List<UnifiedArticle>();

    sfdcJuice_Config__mdt config = sfdcJuiceConfigService.getActiveConfig();
    if (config == null || !sfdcJuiceConfigService.validateConfig(config)) {
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: No valid configuration found for getPopularArticles'
      );
      return articles;
    }

    try {
      // Get base URL from Named Credential or Custom Metadata
      String baseUrl = sfdcJuiceConfigService.getBaseUrl(config);
      if (String.isBlank(baseUrl)) {
        System.debug(LoggingLevel.ERROR, 'HelpjuiceApiService: Base URL not configured');
        return articles;
      }

      // Get API key securely
      String apiKey = sfdcJuiceConfigService.getApiKey(config);
      if (String.isBlank(apiKey)) {
        System.debug(LoggingLevel.ERROR, 'HelpjuiceApiService: API Key not configured');
        return articles;
      }

      // Handle Named Credential endpoint vs regular URL
      String endpoint;
      if (baseUrl.startsWith('callout:')) {
        // Named Credential endpoint - append the API path
        endpoint = baseUrl + ARTICLES_ENDPOINT;
      } else {
        // Regular URL - trim and append
        baseUrl = baseUrl.trim();
        if (baseUrl.endsWith('/')) {
          baseUrl = baseUrl.removeEnd('/');
        }
        endpoint = baseUrl + ARTICLES_ENDPOINT;
      }
      Integer timeout = config.Request_Timeout_Seconds__c != null 
        ? (Integer) config.Request_Timeout_Seconds__c 
        : 30;

      // Build query parameters - filter for published articles only
      Map<String, String> queryParams = new Map<String, String>();
      queryParams.put('filter[is_published]', 'true');
      // Note: Helpjuice API doesn't have a direct "popular" sort, but we can filter and sort by views
      // We'll need to fetch and sort in Apex, or rely on Helpjuice's default ordering

      String queryString = '';
      for (String key : queryParams.keySet()) {
        if (String.isNotBlank(queryString)) {
          queryString += '&';
        }
        queryString += key + '=' + queryParams.get(key);
      }

      endpoint += '?' + queryString;

      HttpRequest req = new HttpRequest();
      req.setEndpoint(endpoint);
      req.setMethod('GET');
      req.setHeader('Authorization', apiKey);
      req.setHeader('Accept', 'application/json');
      req.setHeader('Content-Type', 'application/json');
      req.setTimeout(timeout * 1000);

      Http http = new Http();
      HttpResponse res = http.send(req);

      if (res.getStatusCode() == 200) {
        articles = parseArticlesResponse(res.getBody(), maxResults);
        System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Retrieved ' + articles.size() + ' popular articles');
      } else {
        System.debug(
          LoggingLevel.ERROR,
          'HelpjuiceApiService: API error retrieving popular articles: ' +
          res.getStatusCode() +
          ' - ' +
          res.getBody()
        );
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error retrieving Helpjuice popular articles: ' + e.getMessage()
      );
    }

    return articles;
  }

  /**
   * @description Retrieves all categories from Helpjuice
   * @return List<HelpjuiceCategory> List of categories
   */
  @AuraEnabled(cacheable=false)
  public static List<HelpjuiceCategory> getCategories() {
    List<HelpjuiceCategory> categories = new List<HelpjuiceCategory>();

    sfdcJuice_Config__mdt config = sfdcJuiceConfigService.getActiveConfig();
    if (config == null || !sfdcJuiceConfigService.validateConfig(config)) {
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: No valid configuration found for getCategories'
      );
      return categories;
    }

    try {
      // Get base URL from Named Credential or Custom Metadata
      String baseUrl = sfdcJuiceConfigService.getBaseUrl(config);
      if (String.isBlank(baseUrl)) {
        System.debug(LoggingLevel.ERROR, 'HelpjuiceApiService: Base URL not configured');
        return categories;
      }

      // Get API key securely
      String apiKey = sfdcJuiceConfigService.getApiKey(config);
      if (String.isBlank(apiKey)) {
        System.debug(LoggingLevel.ERROR, 'HelpjuiceApiService: API Key not configured');
        return categories;
      }

      // Handle Named Credential endpoint vs regular URL
      String endpoint;
      if (baseUrl.startsWith('callout:')) {
        // Named Credential endpoint - append the API path
        endpoint = baseUrl + CATEGORIES_ENDPOINT;
      } else {
        // Regular URL - trim and append
        baseUrl = baseUrl.trim();
        if (baseUrl.endsWith('/')) {
          baseUrl = baseUrl.removeEnd('/');
        }
        endpoint = baseUrl + CATEGORIES_ENDPOINT;
      }
      Integer timeout = config.Request_Timeout_Seconds__c != null 
        ? (Integer) config.Request_Timeout_Seconds__c 
        : 30;

      HttpRequest req = new HttpRequest();
      req.setEndpoint(endpoint);
      req.setMethod('GET');
      req.setHeader('Authorization', apiKey);
      req.setHeader('Accept', 'application/json');
      req.setHeader('Content-Type', 'application/json');
      req.setTimeout(timeout * 1000);

      Http http = new Http();
      HttpResponse res = http.send(req);

      if (res.getStatusCode() == 200) {
        categories = parseCategoriesResponse(res.getBody());
        System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Retrieved ' + categories.size() + ' categories');
      } else {
        System.debug(
          LoggingLevel.ERROR,
          'HelpjuiceApiService: API error retrieving categories: ' +
          res.getStatusCode() +
          ' - ' +
          res.getBody()
        );
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error retrieving Helpjuice categories: ' + e.getMessage()
      );
    }

    return categories;
  }

  /**
   * @description Parses the Helpjuice search API response
   * @param jsonResponse The JSON response body
   * @return List<UnifiedArticle> List of unified articles
   */
  private static List<UnifiedArticle> parseSearchResponse(String jsonResponse) {
    List<UnifiedArticle> articles = new List<UnifiedArticle>();

    if (String.isBlank(jsonResponse)) {
      System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Empty response body');
      return articles;
    }

    try {
      Object responseObj = JSON.deserializeUntyped(jsonResponse);
      
      // Check if response is directly an array of articles
      if (responseObj instanceof List<Object>) {
        List<Object> articlesList = (List<Object>) responseObj;
        System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Response is array with ' + articlesList.size() + ' items');
        
        for (Object articleObj : articlesList) {
          if (articleObj instanceof Map<String, Object>) {
            Map<String, Object> articleMap = (Map<String, Object>) articleObj;
            UnifiedArticle article = mapHelpjuiceArticleToUnified(articleMap);
            if (article != null && String.isNotBlank(article.id)) {
              articles.add(article);
            }
          }
        }
      }
      // Check if response is a map/object
      else if (responseObj instanceof Map<String, Object>) {
        Map<String, Object> responseMap = (Map<String, Object>) responseObj;
        System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Response keys: ' + responseMap.keySet());

        // Helpjuice API v3 search endpoint returns results in a "searches" array
        // See: https://help.helpjuice.com/en_US/api-v3/using-api-v3
        if (responseMap.containsKey('searches')) {
          Object searchesObj = responseMap.get('searches');
          if (searchesObj instanceof List<Object>) {
            List<Object> searchesList = (List<Object>) searchesObj;
            System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Found ' + searchesList.size() + ' search results in response');

            for (Object searchObj : searchesList) {
              if (searchObj instanceof Map<String, Object>) {
                Map<String, Object> searchMap = (Map<String, Object>) searchObj;
                UnifiedArticle article = mapHelpjuiceSearchResultToUnified(searchMap);
                if (article != null && String.isNotBlank(article.id)) {
                  articles.add(article);
                } else {
                  System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Skipped invalid search result: ' + searchMap);
                }
              }
            }
          }
        }
        // Also check for "articles" array (for backward compatibility or other endpoints)
        else if (responseMap.containsKey('articles')) {
          Object articlesObj = responseMap.get('articles');
          if (articlesObj instanceof List<Object>) {
            List<Object> articlesList = (List<Object>) articlesObj;
            System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Found ' + articlesList.size() + ' articles in response');

            for (Object articleObj : articlesList) {
              if (articleObj instanceof Map<String, Object>) {
                Map<String, Object> articleMap = (Map<String, Object>) articleObj;
                UnifiedArticle article = mapHelpjuiceArticleToUnified(articleMap);
                if (article != null && String.isNotBlank(article.id)) {
                  articles.add(article);
                } else {
                  System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Skipped invalid article: ' + articleMap);
                }
              }
            }
          }
        }
        // Check for error messages in response
        else if (responseMap.containsKey('error') || responseMap.containsKey('message')) {
          String errorMsg = responseMap.containsKey('error') 
            ? String.valueOf(responseMap.get('error'))
            : String.valueOf(responseMap.get('message'));
          System.debug(LoggingLevel.ERROR, 'HelpjuiceApiService: API returned error: ' + errorMsg);
          throw new AuraHandledException('Helpjuice API error: ' + errorMsg);
        }
        else {
          System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Unexpected response format. Keys: ' + responseMap.keySet());
          System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Response preview: ' + jsonResponse.substring(0, Math.min(500, jsonResponse.length())));
        }
      }
      else {
        System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Unexpected response type: ' + responseObj);
        System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Response preview: ' + jsonResponse.substring(0, Math.min(500, jsonResponse.length())));
      }
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: Error parsing response: ' + e.getMessage()
      );
      System.debug(LoggingLevel.ERROR, 'Response body: ' + jsonResponse.substring(0, Math.min(1000, jsonResponse.length())));
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
      throw new AuraHandledException(
        'Error parsing Helpjuice API response: ' + e.getMessage()
      );
    }

    return articles;
  }

  /**
   * @description Parses a single Helpjuice article response
   * @param jsonResponse The JSON response body
   * @return UnifiedArticle The unified article
   */
  private static UnifiedArticle parseArticleResponse(String jsonResponse) {
    try {
      Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(
        jsonResponse
      );

      // Helpjuice API v3 single article endpoint can return:
      // 1. { article: { ... } } - wrapped in article object
      // 2. { id: ..., name: ..., ... } - direct article object
      Map<String, Object> articleMap = null;
      
      if (responseMap.containsKey('article')) {
        articleMap = (Map<String, Object>) responseMap.get('article');
      } else if (responseMap.containsKey('id')) {
        // Direct article object (no wrapper)
        articleMap = responseMap;
      } else {
        System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Unexpected article response format. Keys: ' + responseMap.keySet());
        System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Response preview: ' + jsonResponse.substring(0, Math.min(500, jsonResponse.length())));
        return null;
      }
      
      if (articleMap != null) {
        UnifiedArticle article = mapHelpjuiceArticleToUnified(articleMap);
        if (article == null) {
          System.debug(LoggingLevel.ERROR, 'HelpjuiceApiService: mapHelpjuiceArticleToUnified returned null');
          System.debug(LoggingLevel.ERROR, 'HelpjuiceApiService: Article map keys: ' + articleMap.keySet());
        }
        return article;
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error parsing Helpjuice article response: ' + e.getMessage()
      );
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
      System.debug(LoggingLevel.ERROR, 'Response body: ' + jsonResponse.substring(0, Math.min(1000, jsonResponse.length())));
      throw new AuraHandledException(
        'Error parsing Helpjuice article response: ' + e.getMessage()
      );
    }

    return null;
  }

  /**
   * @description Maps a Helpjuice search result to UnifiedArticle
   * @param searchMap The Helpjuice search result data from /api/v3/search
   * @return UnifiedArticle The unified article representation
   */
  private static UnifiedArticle mapHelpjuiceSearchResultToUnified(
    Map<String, Object> searchMap
  ) {
    UnifiedArticle article = new UnifiedArticle();
    article.source = 'Helpjuice';

    try {
      // Map ID
      if (searchMap.containsKey('id')) {
        article.id = String.valueOf(searchMap.get('id'));
      }

      // Map name (search results use 'name' instead of 'title')
      if (searchMap.containsKey('name')) {
        article.title = String.valueOf(searchMap.get('name'));
      }

      // Map answer_sample as snippet (short answer)
      if (searchMap.containsKey('answer_sample')) {
        article.snippet = String.valueOf(searchMap.get('answer_sample'));
      }
      // Use long_answer_sample if answer_sample is not available
      else if (searchMap.containsKey('long_answer_sample')) {
        article.snippet = String.valueOf(searchMap.get('long_answer_sample'));
      }

      // Map long_answer_sample as content (longer answer)
      if (searchMap.containsKey('long_answer_sample')) {
        article.content = String.valueOf(searchMap.get('long_answer_sample'));
      }
      // Fall back to answer_sample if long_answer_sample is not available
      else if (searchMap.containsKey('answer_sample')) {
        article.content = String.valueOf(searchMap.get('answer_sample'));
      }

      // Map URL
      if (searchMap.containsKey('url')) {
        article.url = String.valueOf(searchMap.get('url'));
      }
      // If URL is not provided, try to construct it from base URL and slug
      // Helpjuice URLs typically follow: https://<account>.helpjuice.com/<slug>
      else if (searchMap.containsKey('slug')) {
        String slug = String.valueOf(searchMap.get('slug'));
        sfdcJuice_Config__mdt config = sfdcJuiceConfigService.getActiveConfig();
        if (config != null) {
          String baseUrl = sfdcJuiceConfigService.getBaseUrl(config);
          // For URL construction, we need the actual URL, not the callout: reference
          if (String.isNotBlank(baseUrl) && !baseUrl.startsWith('callout:')) {
            baseUrl = baseUrl.trim();
            if (baseUrl.endsWith('/')) {
              baseUrl = baseUrl.removeEnd('/');
            }
            // Construct URL: baseUrl + '/' + slug
            article.url = baseUrl + '/' + slug;
          } else if (String.isNotBlank(config.Helpjuice_Base_URL__c)) {
            // Fallback to direct field access for URL construction
            baseUrl = config.Helpjuice_Base_URL__c.trim();
            if (baseUrl.endsWith('/')) {
              baseUrl = baseUrl.removeEnd('/');
            }
            article.url = baseUrl + '/' + slug;
          }
        }
      }

      // Map tag_names as tags
      if (searchMap.containsKey('tag_names') && searchMap.get('tag_names') instanceof List<Object>) {
        List<Object> tagNames = (List<Object>) searchMap.get('tag_names');
        article.tags = new List<String>();
        for (Object tagObj : tagNames) {
          article.tags.add(String.valueOf(tagObj));
        }
      }

      // Map categories
      if (searchMap.containsKey('categories') && searchMap.get('categories') instanceof Map<String, Object>) {
        Map<String, Object> categoriesMap = (Map<String, Object>) searchMap.get('categories');
        article.categories = new List<String>();
        if (categoriesMap.containsKey('current') && categoriesMap.get('current') instanceof Map<String, Object>) {
          Map<String, Object> currentCategory = (Map<String, Object>) categoriesMap.get('current');
          if (currentCategory.containsKey('name')) {
            article.categories.add(String.valueOf(currentCategory.get('name')));
          }
        }
      }

      // Map dates - try multiple fields and formats
      DateTime parsedPublishedDate = null;
      DateTime parsedLastModifiedDate = null;
      
      // Try updated_at first (most accurate for lastModifiedDate, ISO 8601 format)
      if (searchMap.containsKey('updated_at')) {
        String updatedAtStr = String.valueOf(searchMap.get('updated_at'));
        if (String.isNotBlank(updatedAtStr) && !updatedAtStr.equals('null')) {
          parsedLastModifiedDate = parseDateTime(updatedAtStr);
          if (parsedLastModifiedDate != null) {
            article.lastModifiedDate = parsedLastModifiedDate;
          }
        }
      }
      
      // Try created_at for publishedDate (ISO 8601 format)
      if (searchMap.containsKey('created_at')) {
        String createdAtStr = String.valueOf(searchMap.get('created_at'));
        if (String.isNotBlank(createdAtStr) && !createdAtStr.equals('null')) {
          parsedPublishedDate = parseDateTime(createdAtStr);
          if (parsedPublishedDate != null) {
            article.publishedDate = parsedPublishedDate;
            // Use created_at as fallback for lastModifiedDate if updated_at wasn't available
            if (parsedLastModifiedDate == null) {
              article.lastModifiedDate = parsedPublishedDate;
            }
          }
        }
      }
      
      // Try last_published_date (formatted string like "July 30th, 2020")
      if (searchMap.containsKey('last_published_date')) {
        String dateStr = String.valueOf(searchMap.get('last_published_date'));
        if (String.isNotBlank(dateStr) && !dateStr.equals('null')) {
          try {
            DateTime parsedDate = parseDateString(dateStr);
            if (parsedDate != null) {
              if (parsedPublishedDate == null) {
                article.publishedDate = parsedDate;
              }
              // Use last_published_date for lastModifiedDate if we don't have updated_at or created_at
              if (parsedLastModifiedDate == null) {
                article.lastModifiedDate = parsedDate;
              }
            }
          } catch (Exception e) {
            System.debug(
              LoggingLevel.WARN,
              'HelpjuiceApiService: Could not parse last_published_date: ' + dateStr + ' - ' + e.getMessage()
            );
          }
        }
      }

      // Map last_published_user_name as author
      if (searchMap.containsKey('last_published_user_name')) {
        article.authorName = String.valueOf(searchMap.get('last_published_user_name'));
      }

      // Map is_published, is_internal, is_private to metadata
      if (searchMap.containsKey('is_published')) {
        article.metadata.put('is_published', searchMap.get('is_published'));
      }
      if (searchMap.containsKey('is_internal')) {
        article.metadata.put('is_internal', searchMap.get('is_internal'));
      }
      if (searchMap.containsKey('is_private')) {
        article.metadata.put('is_private', searchMap.get('is_private'));
      }
      if (searchMap.containsKey('slug')) {
        article.metadata.put('slug', searchMap.get('slug'));
      }

      article.articleType = 'Helpjuice';
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error mapping Helpjuice search result: ' + e.getMessage()
      );
      System.debug(LoggingLevel.ERROR, 'Search map: ' + searchMap);
      return null;
    }

    return article;
  }

  /**
   * @description Maps a Helpjuice article object to UnifiedArticle (for article detail endpoints)
   * @param articleMap The Helpjuice article data
   * @return UnifiedArticle The unified article representation
   */
  private static UnifiedArticle mapHelpjuiceArticleToUnified(
    Map<String, Object> articleMap
  ) {
    UnifiedArticle article = new UnifiedArticle();
    article.source = 'Helpjuice';

    try {
      // Map ID
      if (articleMap.containsKey('id')) {
        article.id = String.valueOf(articleMap.get('id'));
      }

      // Map title - articles endpoint uses 'name' (not 'title')
      if (articleMap.containsKey('name')) {
        article.title = String.valueOf(articleMap.get('name'));
      } else if (articleMap.containsKey('title')) {
        article.title = String.valueOf(articleMap.get('title'));
      }

      // Map content (can be HTML) - articles endpoint has 'answer' array
      System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Article map keys: ' + articleMap.keySet());
      
      // Try to extract content from answer array (primary method)
      if (articleMap.containsKey('answer')) {
        Object answerObj = articleMap.get('answer');
        
        // Handle answer as List (array of answer objects)
        if (answerObj instanceof List<Object>) {
          List<Object> answerList = (List<Object>) answerObj;
          System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Answer list size: ' + answerList.size());
          
          if (!answerList.isEmpty()) {
            // Try each answer object in the list
            for (Integer i = 0; i < answerList.size(); i++) {
              Object answerItem = answerList[i];
              if (answerItem instanceof Map<String, Object>) {
                Map<String, Object> answerMap = (Map<String, Object>) answerItem;
                System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Answer[' + i + '] map keys: ' + answerMap.keySet());
                
                // Prefer processed_body (formatted HTML with proper structure) over body (raw HTML)
                if (answerMap.containsKey('processed_body') && String.isBlank(article.content)) {
                  String processedBody = String.valueOf(answerMap.get('processed_body'));
                  if (String.isNotBlank(processedBody)) {
                    article.content = processedBody;
                    System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Set content from processed_body (length: ' + processedBody.length() + ')');
                    break; // Found content, stop searching
                  }
                }
                if (answerMap.containsKey('body') && String.isBlank(article.content)) {
                  String body = String.valueOf(answerMap.get('body'));
                  if (String.isNotBlank(body)) {
                    article.content = body;
                    System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Set content from body (length: ' + body.length() + ')');
                    break; // Found content, stop searching
                  }
                }
                
                // Use body_txt for snippet if available (use first answer's body_txt)
                if (answerMap.containsKey('body_txt') && String.isBlank(article.snippet)) {
                  article.snippet = String.valueOf(answerMap.get('body_txt'));
                }
              }
            }
          } else {
            System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Answer list is empty');
          }
        }
        // Handle answer as Map (single answer object)
        else if (answerObj instanceof Map<String, Object>) {
          Map<String, Object> answerMap = (Map<String, Object>) answerObj;
          System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Answer is a Map with keys: ' + answerMap.keySet());
          
          // Prefer processed_body over body
          if (answerMap.containsKey('processed_body')) {
            String processedBody = String.valueOf(answerMap.get('processed_body'));
            if (String.isNotBlank(processedBody)) {
              article.content = processedBody;
              System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Set content from processed_body (length: ' + processedBody.length() + ')');
            }
          } else if (answerMap.containsKey('body')) {
            String body = String.valueOf(answerMap.get('body'));
            if (String.isNotBlank(body)) {
              article.content = body;
              System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Set content from body (length: ' + body.length() + ')');
            }
          }
          
          // Use body_txt for snippet if available
          if (answerMap.containsKey('body_txt')) {
            article.snippet = String.valueOf(answerMap.get('body_txt'));
          }
        }
        // Handle answer as String (unlikely but possible)
        else if (answerObj instanceof String) {
          String answerStr = (String) answerObj;
          if (String.isNotBlank(answerStr)) {
            article.content = answerStr;
            System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Set content from answer string (length: ' + answerStr.length() + ')');
          }
        }
        else {
          System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Answer is not a List, Map, or String. Type: ' + answerObj);
        }
      } else {
        System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Article map does not contain answer field');
      }
      
      // Fallback to direct content field
      if (String.isBlank(article.content) && articleMap.containsKey('content')) {
        String content = String.valueOf(articleMap.get('content'));
        if (String.isNotBlank(content)) {
          article.content = content;
          System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Set content from direct content field (length: ' + content.length() + ')');
        }
      }
      
      // Additional fallback: check for other possible content fields
      if (String.isBlank(article.content)) {
        System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Content is still blank after all attempts');
        System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Article map all keys: ' + articleMap.keySet());
        // Log the first 20 keys to help debug
        Integer keyCount = 0;
        for (String key : articleMap.keySet()) {
          if (keyCount < 20) {
            Object value = articleMap.get(key);
            String valueType = value instanceof List<Object> ? 'List' : 
                             value instanceof Map<String, Object> ? 'Map' : 
                             value instanceof String ? 'String (' + ((String) value).length() + ' chars)' : 
                             value != null ? 'Unknown' : 'Null';
            System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Key: ' + key + ', Type: ' + valueType);
            // If it's a string and contains HTML-like content, log a preview
            if (value instanceof String && ((String) value).length() > 50) {
              String preview = ((String) value).substring(0, Math.min(100, ((String) value).length()));
              System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Key: ' + key + ', Preview: ' + preview);
            }
            keyCount++;
          }
        }
      }

      // Map snippet/description
      if (articleMap.containsKey('description')) {
        article.snippet = String.isBlank(article.snippet) 
          ? String.valueOf(articleMap.get('description'))
          : article.snippet;
      } else if (articleMap.containsKey('snippet')) {
        article.snippet = String.isBlank(article.snippet)
          ? String.valueOf(articleMap.get('snippet'))
          : article.snippet;
      }

      // Map URL
      if (articleMap.containsKey('url')) {
        article.url = String.valueOf(articleMap.get('url'));
      }
      // If URL is not provided, try to construct it from base URL and slug/codename
      // Helpjuice URLs typically follow: https://<account>.helpjuice.com/<slug>
      else if (articleMap.containsKey('slug')) {
        String slug = String.valueOf(articleMap.get('slug'));
        sfdcJuice_Config__mdt config = sfdcJuiceConfigService.getActiveConfig();
        if (config != null) {
          String baseUrl = sfdcJuiceConfigService.getBaseUrl(config);
          // For URL construction, we need the actual URL, not the callout: reference
          if (String.isNotBlank(baseUrl) && !baseUrl.startsWith('callout:')) {
            baseUrl = baseUrl.trim();
            if (baseUrl.endsWith('/')) {
              baseUrl = baseUrl.removeEnd('/');
            }
            // Construct URL: baseUrl + '/' + slug
            article.url = baseUrl + '/' + slug;
          } else if (String.isNotBlank(config.Helpjuice_Base_URL__c)) {
            // Fallback to direct field access for URL construction
            baseUrl = config.Helpjuice_Base_URL__c.trim();
            if (baseUrl.endsWith('/')) {
              baseUrl = baseUrl.removeEnd('/');
            }
            article.url = baseUrl + '/' + slug;
          }
        }
      } else if (articleMap.containsKey('codename')) {
        String codename = String.valueOf(articleMap.get('codename'));
        sfdcJuice_Config__mdt config = sfdcJuiceConfigService.getActiveConfig();
        if (config != null) {
          String baseUrl = sfdcJuiceConfigService.getBaseUrl(config);
          // For URL construction, we need the actual URL, not the callout: reference
          if (String.isNotBlank(baseUrl) && !baseUrl.startsWith('callout:')) {
            baseUrl = baseUrl.trim();
            if (baseUrl.endsWith('/')) {
              baseUrl = baseUrl.removeEnd('/');
            }
            // Construct URL: baseUrl + '/' + codename
            article.url = baseUrl + '/' + codename;
          } else if (String.isNotBlank(config.Helpjuice_Base_URL__c)) {
            // Fallback to direct field access for URL construction
            baseUrl = config.Helpjuice_Base_URL__c.trim();
            if (baseUrl.endsWith('/')) {
              baseUrl = baseUrl.removeEnd('/');
            }
            article.url = baseUrl + '/' + codename;
          }
        }
      }

      // Map tags - articles endpoint uses 'keywords' (array of objects with 'name')
      if (articleMap.containsKey('keywords') && articleMap.get('keywords') instanceof List<Object>) {
        List<Object> keywordsList = (List<Object>) articleMap.get('keywords');
        article.tags = new List<String>();
        for (Object keywordObj : keywordsList) {
          if (keywordObj instanceof Map<String, Object>) {
            Map<String, Object> keywordMap = (Map<String, Object>) keywordObj;
            if (keywordMap.containsKey('name')) {
              article.tags.add(String.valueOf(keywordMap.get('name')));
            }
          } else {
            article.tags.add(String.valueOf(keywordObj));
          }
        }
      }
      // Fallback to 'tags' field if 'keywords' is not available
      else if (articleMap.containsKey('tags')) {
        Object tagsObj = articleMap.get('tags');
        if (tagsObj instanceof List<Object>) {
          List<Object> tagsList = (List<Object>) tagsObj;
          article.tags = new List<String>();
          for (Object tagObj : tagsList) {
            if (tagObj instanceof Map<String, Object>) {
              Map<String, Object> tagMap = (Map<String, Object>) tagObj;
              if (tagMap.containsKey('name')) {
                article.tags.add(String.valueOf(tagMap.get('name')));
              }
            } else {
              article.tags.add(String.valueOf(tagObj));
            }
          }
        }
      }

      // Map categories
      if (articleMap.containsKey('categories')) {
        Object categoriesObj = articleMap.get('categories');
        if (categoriesObj instanceof List<Object>) {
          List<Object> categoriesList = (List<Object>) categoriesObj;
          for (Object categoryObj : categoriesList) {
            if (categoryObj instanceof Map<String, Object>) {
              Map<String, Object> categoryMap = (Map<String, Object>) categoryObj;
              if (categoryMap.containsKey('name')) {
                article.categories.add(
                  String.valueOf(categoryMap.get('name'))
                );
              }
            } else {
              article.categories.add(String.valueOf(categoryObj));
            }
          }
        }
      }

      // Map dates
      if (articleMap.containsKey('created_at')) {
        String createdAtStr = String.valueOf(articleMap.get('created_at'));
        article.publishedDate = parseDateTime(createdAtStr);
      }

      if (articleMap.containsKey('updated_at')) {
        String updatedAtStr = String.valueOf(articleMap.get('updated_at'));
        article.lastModifiedDate = parseDateTime(updatedAtStr);
      }

      // Map author
      if (articleMap.containsKey('author')) {
        Object authorObj = articleMap.get('author');
        if (authorObj instanceof Map<String, Object>) {
          Map<String, Object> authorMap = (Map<String, Object>) authorObj;
          if (authorMap.containsKey('name')) {
            article.authorName = String.valueOf(authorMap.get('name'));
          }
        }
      }

      // Map language
      if (articleMap.containsKey('language')) {
        article.language = String.valueOf(articleMap.get('language'));
      }

      // Map view count - articles endpoint uses 'views' (not 'views_count')
      if (articleMap.containsKey('views')) {
        try {
          article.viewCount = Integer.valueOf(articleMap.get('views'));
        } catch (Exception e) {
          article.viewCount = 0;
        }
      } else if (articleMap.containsKey('views_count')) {
        try {
          article.viewCount = Integer.valueOf(articleMap.get('views_count'));
        } catch (Exception e) {
          article.viewCount = 0;
        }
      }

      // Map upvote count
      if (articleMap.containsKey('upvotes_count')) {
        article.upvoteCount = Integer.valueOf(articleMap.get('upvotes_count'));
      }

      // Store all other fields in metadata
      for (String key : articleMap.keySet()) {
        if (
          !key.equals('id') &&
          !key.equals('title') &&
          !key.equals('content') &&
          !key.equals('description') &&
          !key.equals('snippet') &&
          !key.equals('url') &&
          !key.equals('tags') &&
          !key.equals('categories') &&
          !key.equals('created_at') &&
          !key.equals('updated_at') &&
          !key.equals('author') &&
          !key.equals('language') &&
          !key.equals('views_count') &&
          !key.equals('upvotes_count')
        ) {
          article.metadata.put(key, articleMap.get(key));
        }
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error mapping Helpjuice article: ' + e.getMessage()
      );
      return null;
    }

    return article;
  }

  /**
   * @description Parses ISO 8601 datetime string to DateTime
   * @param dateTimeStr ISO 8601 formatted datetime string
   * @return DateTime Parsed DateTime object
   */
  private static DateTime parseDateTime(String dateTimeStr) {
    if (String.isBlank(dateTimeStr)) {
      return null;
    }

    try {
      // Helpjuice uses ISO 8601 format: 2020-07-08T13:50:20.949Z
      // Remove milliseconds and timezone for parsing
      String cleaned = dateTimeStr.replace('Z', '').replace('T', ' ');
      if (cleaned.contains('.')) {
        cleaned = cleaned.substring(0, cleaned.indexOf('.'));
      }

      return DateTime.valueOf(cleaned);
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'Could not parse datetime: ' + dateTimeStr
      );
      return null;
    }
  }

  /**
   * @description Parses date string from Helpjuice search results (e.g., "July 30th, 2020" or "May 3rd, 2024")
   * @param dateStr Date string in format like "July 30th, 2020" or "May 3rd, 2024"
   * @return DateTime Parsed DateTime object, or null if parsing fails
   */
  private static DateTime parseDateString(String dateStr) {
    if (String.isBlank(dateStr)) {
      return null;
    }

    try {
      // Helpjuice search results use format like "July 30th, 2020" or "May 3rd, 2024"
      // Remove ordinal suffixes (st, nd, rd, th)
      String cleaned = dateStr.replaceAll('(\\d+)(st|nd|rd|th)', '$1').trim();
      
      // Map month names to numbers
      Map<String, Integer> monthMap = new Map<String, Integer>{
        'January' => 1, 'February' => 2, 'March' => 3, 'April' => 4,
        'May' => 5, 'June' => 6, 'July' => 7, 'August' => 8,
        'September' => 9, 'October' => 10, 'November' => 11, 'December' => 12
      };
      
      // Parse format: "Month Day, Year" (e.g., "May 3, 2024")
      // Use string manipulation instead of regex for better reliability
      cleaned = cleaned.trim();
      
      // Find the comma that separates day and year
      Integer commaIndex = cleaned.indexOf(',');
      if (commaIndex == -1) {
        return null;
      }
      
      // Extract year (after comma)
      String yearPart = cleaned.substring(commaIndex + 1).trim();
      if (yearPart.length() != 4) {
        return null;
      }
      Integer year = Integer.valueOf(yearPart);
      
      // Extract month and day (before comma)
      String monthDayPart = cleaned.substring(0, commaIndex).trim();
      
      // Find the last space to separate month and day
      Integer lastSpaceIndex = monthDayPart.lastIndexOf(' ');
      if (lastSpaceIndex == -1) {
        return null;
      }
      
      // Extract month name
      String monthName = monthDayPart.substring(0, lastSpaceIndex).trim();
      Integer monthNum = monthMap.get(monthName);
      if (monthNum == null) {
        return null;
      }
      
      // Extract day
      String dayStr = monthDayPart.substring(lastSpaceIndex + 1).trim();
      Integer day = Integer.valueOf(dayStr);
      
      // Create DateTime directly (more reliable than parsing string)
      return DateTime.newInstance(year, monthNum, day, 0, 0, 0);
      
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'HelpjuiceApiService: Could not parse date string: ' + dateStr + ' - ' + e.getMessage()
      );
      return null;
    }
  }

  /**
   * @description Parses error responses from Helpjuice API to extract meaningful error messages
   * @param statusCode HTTP status code
   * @param errorBody Error response body (JSON string)
   * @param searchQuery The original search query that caused the error
   * @return String User-friendly error message
   */
  private static String parseErrorResponse(
    Integer statusCode,
    String errorBody,
    String searchQuery
  ) {
    String errorMessage = 'Helpjuice API error: ' + statusCode;

    if (String.isBlank(errorBody)) {
      return errorMessage + '. No error details provided.';
    }

    try {
      // Parse JSON error response
      Map<String, Object> errorMap = (Map<String, Object>) JSON.deserializeUntyped(
        errorBody
      );

      // Handle 422 Unprocessable Entity (validation errors)
      if (statusCode == 422) {
        List<String> errorMessages = new List<String>();

        // Check for query validation errors
        if (errorMap.containsKey('query')) {
          Object queryError = errorMap.get('query');
          if (queryError instanceof List<Object>) {
            List<Object> queryErrors = (List<Object>) queryError;
            for (Object err : queryErrors) {
              String errMsg = String.valueOf(err);
              if (errMsg.contains('invalid') || errMsg.contains('required')) {
                errorMessages.add(
                  'Search query "' +
                  searchQuery +
                  '" is invalid. ' +
                  'Please try a longer or more specific search query (minimum 3 characters recommended).'
                );
              } else {
                errorMessages.add('Query error: ' + errMsg);
              }
            }
          } else {
            String errMsg = String.valueOf(queryError);
            if (errMsg.contains('invalid') || errMsg.contains('required')) {
              errorMessages.add(
                'Search query "' +
                searchQuery +
                '" is invalid. ' +
                'Please try a longer or more specific search query (minimum 3 characters recommended).'
              );
            } else {
              errorMessages.add('Query error: ' + errMsg);
            }
          }
        }

        // Check for other validation errors
        if (errorMap.containsKey('errors')) {
          Object errors = errorMap.get('errors');
          if (errors instanceof Map<String, Object>) {
            Map<String, Object> errorsMap = (Map<String, Object>) errors;
            for (String key : errorsMap.keySet()) {
              Object errorValue = errorsMap.get(key);
              if (errorValue instanceof List<Object>) {
                List<Object> errorList = (List<Object>) errorValue;
                for (Object err : errorList) {
                  errorMessages.add(key + ': ' + String.valueOf(err));
                }
              } else {
                errorMessages.add(key + ': ' + String.valueOf(errorValue));
              }
            }
          }
        }

        // Check for general error message
        if (errorMap.containsKey('message')) {
          errorMessages.add(String.valueOf(errorMap.get('message')));
        }

        if (errorMap.containsKey('error')) {
          errorMessages.add(String.valueOf(errorMap.get('error')));
        }

        if (!errorMessages.isEmpty()) {
          return String.join(errorMessages, ' ');
        }
      }

      // Handle 401 Unauthorized
      if (statusCode == 401) {
        return 'Helpjuice API authentication failed. Please verify your API key in Custom Metadata.';
      }

      // Handle 403 Forbidden
      if (statusCode == 403) {
        return 'Helpjuice API access forbidden. Please check your API key permissions.';
      }

      // Handle 404 Not Found
      if (statusCode == 404) {
        return 'Helpjuice API endpoint not found. Please verify your Base URL in Custom Metadata.';
      }

      // Handle other errors
      if (errorMap.containsKey('message')) {
        return 'Helpjuice API error (' +
          statusCode +
          '): ' +
          String.valueOf(errorMap.get('message'));
      }

      if (errorMap.containsKey('error')) {
        return 'Helpjuice API error (' +
          statusCode +
          '): ' +
          String.valueOf(errorMap.get('error'));
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'HelpjuiceApiService: Error parsing error response: ' + e.getMessage()
      );
      // Fall back to showing raw error body if JSON parsing fails
      return errorMessage +
        '. Error: ' +
        (errorBody.length() > 200 ? errorBody.substring(0, 200) : errorBody);
    }

    // Fallback: return generic error with truncated body
    return errorMessage +
      '. Error: ' +
      (errorBody.length() > 200 ? errorBody.substring(0, 200) : errorBody);
  }

  /**
   * @description Parses articles response from Helpjuice API
   * @param jsonResponse The JSON response body
   * @param maxResults Maximum number of articles to return
   * @return List<UnifiedArticle> List of unified articles, sorted by views (popular)
   */
  private static List<UnifiedArticle> parseArticlesResponse(String jsonResponse, Integer maxResults) {
    List<UnifiedArticle> articles = new List<UnifiedArticle>();

    if (String.isBlank(jsonResponse)) {
      System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Empty articles response body');
      return articles;
    }

    try {
      Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);

      if (responseMap.containsKey('articles')) {
        Object articlesObj = responseMap.get('articles');
        if (articlesObj instanceof List<Object>) {
          List<Object> articlesList = (List<Object>) articlesObj;
          System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Found ' + articlesList.size() + ' articles in response');

          // Map articles and collect for sorting
          List<UnifiedArticle> mappedArticles = new List<UnifiedArticle>();
          for (Object articleObj : articlesList) {
            if (articleObj instanceof Map<String, Object>) {
              Map<String, Object> articleMap = (Map<String, Object>) articleObj;
              UnifiedArticle article = mapHelpjuiceArticleToUnified(articleMap);
              if (article != null && String.isNotBlank(article.id)) {
                // Extract views count for sorting
                if (articleMap.containsKey('views')) {
                  try {
                    article.viewCount = Integer.valueOf(articleMap.get('views'));
                  } catch (Exception e) {
                    article.viewCount = 0;
                  }
                }
                mappedArticles.add(article);
              }
            }
          }

          // Sort by views (descending) to get popular articles
          mappedArticles.sort(new ArticleViewsComparator());

          // Return top N articles
          for (Integer i = 0; i < Math.min(maxResults, mappedArticles.size()); i++) {
            articles.add(mappedArticles[i]);
          }
        }
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: Error parsing articles response: ' + e.getMessage()
      );
      System.debug(LoggingLevel.ERROR, 'Response body: ' + jsonResponse.substring(0, Math.min(1000, jsonResponse.length())));
    }

    return articles;
  }

  /**
   * @description Parses categories response from Helpjuice API
   * @param jsonResponse The JSON response body
   * @return List<HelpjuiceCategory> List of categories
   */
  private static List<HelpjuiceCategory> parseCategoriesResponse(String jsonResponse) {
    List<HelpjuiceCategory> categories = new List<HelpjuiceCategory>();

    if (String.isBlank(jsonResponse)) {
      System.debug(LoggingLevel.WARN, 'HelpjuiceApiService: Empty categories response body');
      return categories;
    }

    try {
      Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);

      if (responseMap.containsKey('categories')) {
        Object categoriesObj = responseMap.get('categories');
        if (categoriesObj instanceof List<Object>) {
          List<Object> categoriesList = (List<Object>) categoriesObj;
          System.debug(LoggingLevel.INFO, 'HelpjuiceApiService: Found ' + categoriesList.size() + ' categories in response');

          for (Object categoryObj : categoriesList) {
            if (categoryObj instanceof Map<String, Object>) {
              Map<String, Object> categoryMap = (Map<String, Object>) categoryObj;
              HelpjuiceCategory category = mapHelpjuiceCategory(categoryMap);
              if (category != null && String.isNotBlank(category.id)) {
                categories.add(category);
              }
            }
          }
        }
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'HelpjuiceApiService: Error parsing categories response: ' + e.getMessage()
      );
      System.debug(LoggingLevel.ERROR, 'Response body: ' + jsonResponse.substring(0, Math.min(1000, jsonResponse.length())));
    }

    return categories;
  }

  /**
   * @description Maps a Helpjuice category object to HelpjuiceCategory
   * @param categoryMap The Helpjuice category data
   * @return HelpjuiceCategory The category representation
   */
  private static HelpjuiceCategory mapHelpjuiceCategory(Map<String, Object> categoryMap) {
    HelpjuiceCategory category = new HelpjuiceCategory();

    try {
      if (categoryMap.containsKey('id')) {
        category.id = String.valueOf(categoryMap.get('id'));
      }

      if (categoryMap.containsKey('name')) {
        category.name = String.valueOf(categoryMap.get('name'));
      }

      if (categoryMap.containsKey('url')) {
        category.url = String.valueOf(categoryMap.get('url'));
      }

      if (categoryMap.containsKey('description')) {
        category.description = String.valueOf(categoryMap.get('description'));
      }

      if (categoryMap.containsKey('created_at')) {
        String createdAtStr = String.valueOf(categoryMap.get('created_at'));
        category.createdAt = parseDateTime(createdAtStr);
      }

      if (categoryMap.containsKey('updated_at')) {
        String updatedAtStr = String.valueOf(categoryMap.get('updated_at'));
        category.updatedAt = parseDateTime(updatedAtStr);
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error mapping Helpjuice category: ' + e.getMessage()
      );
      return null;
    }

    return category;
  }

  /**
   * @description Comparator class for sorting articles by views (descending)
   */
  private class ArticleViewsComparator implements Comparator<UnifiedArticle> {
    public Integer compare(UnifiedArticle a1, UnifiedArticle a2) {
      Integer views1 = a1.viewCount != null ? a1.viewCount : 0;
      Integer views2 = a2.viewCount != null ? a2.viewCount : 0;
      
      if (views1 > views2) {
        return -1; // a1 comes before a2 (descending)
      } else if (views1 < views2) {
        return 1; // a2 comes before a1 (descending)
      } else {
        return 0; // equal
      }
    }
  }
}

