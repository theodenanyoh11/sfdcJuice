/**
 * @description Main service that unifies Helpjuice and Salesforce Knowledge search
 * @author sfdcJuice
 */
public class UnifiedSearchService {
  /**
   * @description Performs unified search across Helpjuice and Salesforce Knowledge
   * @param request The search request with filters and parameters
   * @return UnifiedSearchResponse The unified search results
   */
  @AuraEnabled(cacheable=false)
  public static UnifiedSearchResponse search(UnifiedSearchRequest request) {
    UnifiedSearchResponse response = new UnifiedSearchResponse();
    response.articles = new List<UnifiedArticle>();
    response.pageNumber = request.pageNumber != null ? request.pageNumber : 1;

    if (request == null || String.isBlank(request.searchQuery)) {
      response.hasError = true;
      response.errorMessage = 'Search query is required';
      return response;
    }

    try {
      // Use the requested maxResults if provided, otherwise use default or config value
      Integer maxResults = request.maxResults != null
        ? request.maxResults
        : 25;

      // Only use Custom Metadata as fallback if maxResults was not provided in request
      if (request.maxResults == null) {
        sfdcJuice_Config__mdt config = sfdcJuiceConfigService.getActiveConfig();
        if (config != null && config.Max_Results_Per_Source__c != null) {
          maxResults = Integer.valueOf(config.Max_Results_Per_Source__c);
        }
      }

      List<UnifiedArticle> helpjuiceArticles = new List<UnifiedArticle>();
      List<UnifiedArticle> salesforceArticles = new List<UnifiedArticle>();

      // Search Helpjuice if source filter allows
      if (
        request.sourceFilter == 'All' || request.sourceFilter == 'Helpjuice'
      ) {
        try {
          helpjuiceArticles = HelpjuiceApiService.searchArticles(
            request.searchQuery,
            maxResults,
            request.pageNumber
          );
          System.debug(
            LoggingLevel.INFO,
            'UnifiedSearchService: Retrieved ' +
            helpjuiceArticles.size() +
            ' Helpjuice articles'
          );
        } catch (AuraHandledException e) {
          // AuraHandledException means we have a user-friendly error message
          String errorMsg = extractErrorMessage(e);
          System.debug(
            LoggingLevel.ERROR,
            'Error searching Helpjuice: ' + errorMsg
          );
          // Always show error to user, but if searching "All", also show Salesforce results
          if (request.sourceFilter == 'Helpjuice') {
            response.hasError = true;
            response.errorMessage = String.isNotBlank(errorMsg) 
              ? errorMsg 
              : 'Error searching Helpjuice. Please check configuration and Remote Site Settings.';
            return response;
          }
          // For "All" searches, continue with Salesforce results but log the error
          // The error will be visible in debug logs but won't block Salesforce results
          System.debug(
            LoggingLevel.WARN,
            'Helpjuice search failed but continuing with Salesforce results only. Error: ' + errorMsg
          );
        } catch (Exception e) {
          String errorMsg = extractErrorMessage(e);
          System.debug(
            LoggingLevel.ERROR,
            'Error searching Helpjuice: ' + errorMsg
          );
          System.debug(
            LoggingLevel.ERROR,
            'Stack trace: ' + e.getStackTraceString()
          );
          // If only searching Helpjuice, return error to user
          if (request.sourceFilter == 'Helpjuice') {
            response.hasError = true;
            response.errorMessage = String.isNotBlank(errorMsg) 
              ? 'Error searching Helpjuice: ' + errorMsg 
              : 'Error searching Helpjuice. Please check configuration and Remote Site Settings.';
            return response;
          }
          // Otherwise, continue with Salesforce results only
          System.debug(
            LoggingLevel.WARN,
            'Helpjuice search failed but continuing with Salesforce results only. Error: ' + errorMsg
          );
        }
      }

      // Search Salesforce Knowledge if source filter allows
      if (
        request.sourceFilter == 'All' ||
        request.sourceFilter == 'Salesforce'
      ) {
        try {
          salesforceArticles = SalesforceKnowledgeService.searchArticles(
            request.searchQuery,
            maxResults,
            request.pageNumber
          );
        } catch (Exception e) {
          System.debug(
            LoggingLevel.ERROR,
            'Error searching Salesforce Knowledge: ' + e.getMessage()
          );
        }
      }

      // Combine and normalize results
      List<UnifiedArticle> allArticles = new List<UnifiedArticle>();
      allArticles.addAll(helpjuiceArticles);
      allArticles.addAll(salesforceArticles);

      // Apply filters
      allArticles = applyFilters(allArticles, request);

      // Sort by relevance (could be enhanced with scoring)
      // For now, sort by last modified date (most recent first)
      allArticles.sort(new ArticleDateComparator());

      // Store total count before pagination
      Integer totalCountBeforePagination = allArticles.size();

      // Apply pagination - limit results to maxResults per page
      Integer startIndex = (response.pageNumber - 1) * maxResults;
      Integer endIndex = startIndex + maxResults;
      
      System.debug(
        LoggingLevel.INFO,
        'UnifiedSearchService: Pagination - pageNumber: ' +
        response.pageNumber +
        ', maxResults: ' +
        maxResults +
        ', totalArticles: ' +
        totalCountBeforePagination +
        ', startIndex: ' +
        startIndex +
        ', endIndex: ' +
        endIndex
      );
      
      if (startIndex < allArticles.size()) {
        if (endIndex > allArticles.size()) {
          endIndex = allArticles.size();
        }
        response.articles = new List<UnifiedArticle>();
        for (Integer i = startIndex; i < endIndex; i++) {
          response.articles.add(allArticles[i]);
        }
      } else {
        response.articles = new List<UnifiedArticle>();
      }

      System.debug(
        LoggingLevel.INFO,
        'UnifiedSearchService: Returning ' +
        response.articles.size() +
        ' articles after pagination'
      );

      response.totalCount = totalCountBeforePagination;
      response.hasMore = endIndex < totalCountBeforePagination;

      // Calculate total pages (simplified - assumes maxResults per page)
      if (maxResults > 0) {
        response.totalPages = (Integer) Math.ceil(
          (Double) response.totalCount / maxResults
        );
      } else {
        response.totalPages = 1;
      }
    } catch (Exception e) {
      response.hasError = true;
      response.errorMessage =
        'An error occurred during search: ' + e.getMessage();
      System.debug(
        LoggingLevel.ERROR,
        'Unified search error: ' + e.getMessage()
      );
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
    }

    return response;
  }

  /**
   * @description Retrieves a single article by ID and source
   * @param articleId The article ID
   * @param source The source ('Helpjuice' or 'Salesforce')
   * @return UnifiedArticle The article, or null if not found
   */
  @AuraEnabled(cacheable=false)
  public static UnifiedArticle getArticle(String articleId, String source) {
    if (String.isBlank(articleId) || String.isBlank(source)) {
      return null;
    }

    UnifiedArticle article = null;

    try {
      if (source == 'Helpjuice') {
        article = HelpjuiceApiService.getArticleById(articleId);
      } else if (source == 'Salesforce') {
        article = SalesforceKnowledgeService.getArticleById(articleId);
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error retrieving article: ' + e.getMessage()
      );
    }

    return article;
  }

  /**
   * @description Applies filters to the article list
   * @param articles The articles to filter
   * @param request The search request with filter criteria
   * @return List<UnifiedArticle> Filtered articles
   */
  private static List<UnifiedArticle> applyFilters(
    List<UnifiedArticle> articles,
    UnifiedSearchRequest request
  ) {
    List<UnifiedArticle> filtered = new List<UnifiedArticle>();

    for (UnifiedArticle article : articles) {
      Boolean include = true;

      // Filter by tags
      if (request.tagFilters != null && !request.tagFilters.isEmpty()) {
        Boolean hasMatchingTag = false;
        for (String filterTag : request.tagFilters) {
          if (article.tags != null && article.tags.contains(filterTag)) {
            hasMatchingTag = true;
            break;
          }
        }
        if (!hasMatchingTag) {
          include = false;
        }
      }

      // Filter by categories
      if (
        request.categoryFilters != null &&
        !request.categoryFilters.isEmpty()
      ) {
        Boolean hasMatchingCategory = false;
        for (String filterCategory : request.categoryFilters) {
          if (
            article.categories != null &&
            article.categories.contains(filterCategory)
          ) {
            hasMatchingCategory = true;
            break;
          }
        }
        if (!hasMatchingCategory) {
          include = false;
        }
      }

      // Filter by date range (using lastModifiedDate)
      if (request.dateFrom != null) {
        // Set dateFrom to start of day (00:00:00) for inclusive comparison
        DateTime dateFromStart = DateTime.newInstance(
          request.dateFrom.year(),
          request.dateFrom.month(),
          request.dateFrom.day(),
          0,
          0,
          0
        );
        if (
          article.lastModifiedDate == null ||
          article.lastModifiedDate < dateFromStart
        ) {
          include = false;
        }
      }

      if (request.dateTo != null) {
        // Set dateTo to end of day (23:59:59) for inclusive comparison
        DateTime dateToEnd = DateTime.newInstance(
          request.dateTo.year(),
          request.dateTo.month(),
          request.dateTo.day(),
          23,
          59,
          59
        );
        if (
          article.lastModifiedDate == null ||
          article.lastModifiedDate > dateToEnd
        ) {
          include = false;
        }
      }

      if (include) {
        filtered.add(article);
      }
    }

    return filtered;
  }

  /**
   * @description Extracts error message from exception, handling various exception types
   * @param e The exception
   * @return String The error message
   */
  private static String extractErrorMessage(Exception e) {
    if (e == null) {
      return 'Unknown error occurred';
    }
    
    String errorMsg = e.getMessage();
    
    // Check if message is blank or generic "Script-thrown exception"
    if (String.isBlank(errorMsg) || 
        (errorMsg != null && errorMsg.contains('Script-thrown'))) {
      // Try to extract from exception string representation
      String exceptionStr = String.valueOf(e);
      if (String.isNotBlank(exceptionStr) && 
          exceptionStr.length() > 50 && 
          !exceptionStr.contains('Script-thrown')) {
        // Try to extract meaningful message from exception string
        if (exceptionStr.contains('Remote site settings')) {
          errorMsg = 'Remote Site Settings not configured. Please add your Helpjuice domain to Remote Site Settings at Setup > Security > Remote Site Settings.';
        } else if (exceptionStr.contains('CalloutException')) {
          errorMsg = 'Failed to connect to Helpjuice API. Please check Remote Site Settings are configured for your Helpjuice domain.';
        } else {
          errorMsg = 'Error connecting to Helpjuice API. Please check: 1) Custom Metadata is configured with your actual API key and Base URL (not placeholders), 2) Remote Site Settings are configured for your Helpjuice domain.';
        }
      } else {
        // Provide generic but helpful error message
        String typeName = e.getTypeName();
        if (typeName != null && typeName.contains('CalloutException')) {
          errorMsg = 'Failed to connect to Helpjuice API. Please check Remote Site Settings are configured for your Helpjuice domain at Setup > Security > Remote Site Settings.';
        } else {
          errorMsg = 'Error connecting to Helpjuice API. Please verify: 1) Custom Metadata has your actual API key and Base URL (not "YOUR_API_KEY_HERE" or "youraccount"), 2) Remote Site Settings are configured for your Helpjuice domain.';
        }
      }
    }
    
    return errorMsg;
  }

  /**
   * @description Retrieves popular articles from Helpjuice (for display when no search query)
   * @param maxResults Maximum number of articles to return
   * @return List<UnifiedArticle> List of popular articles
   */
  @AuraEnabled(cacheable=false)
  public static List<UnifiedArticle> getPopularArticles(Integer maxResults) {
    List<UnifiedArticle> articles = new List<UnifiedArticle>();

    try {
      Integer maxArticles = maxResults != null ? maxResults : 10;
      articles = HelpjuiceApiService.getPopularArticles(maxArticles);
      System.debug(
        LoggingLevel.INFO,
        'UnifiedSearchService: Retrieved ' +
        articles.size() +
        ' popular articles'
      );
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error retrieving popular articles: ' + e.getMessage()
      );
    }

    return articles;
  }

  /**
   * @description Retrieves categories from Helpjuice (for display when no search query)
   * @return List<HelpjuiceCategory> List of categories
   */
  @AuraEnabled(cacheable=false)
  public static List<HelpjuiceCategory> getCategories() {
    List<HelpjuiceCategory> categories = new List<HelpjuiceCategory>();

    try {
      categories = HelpjuiceApiService.getCategories();
      System.debug(
        LoggingLevel.INFO,
        'UnifiedSearchService: Retrieved ' +
        categories.size() +
        ' categories'
      );
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error retrieving categories: ' + e.getMessage()
      );
    }

    return categories;
  }

  /**
   * @description Comparator for sorting articles by date (most recent first)
   */
  private class ArticleDateComparator implements Comparator<UnifiedArticle> {
    public Integer compare(UnifiedArticle a1, UnifiedArticle a2) {
      DateTime d1 = a1.lastModifiedDate != null
        ? a1.lastModifiedDate
        : a1.publishedDate;
      DateTime d2 = a2.lastModifiedDate != null
        ? a2.lastModifiedDate
        : a2.publishedDate;

      if (d1 == null && d2 == null) {
        return 0;
      }
      if (d1 == null) {
        return 1;
      }
      if (d2 == null) {
        return -1;
      }

      if (d1 > d2) {
        return -1;
      } else if (d1 < d2) {
        return 1;
      }
      return 0;
    }
  }
}

