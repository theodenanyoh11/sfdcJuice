/**
 * @description Service for searching Salesforce Knowledge articles
 * @author sfdcJuice
 */
public class SalesforceKnowledgeService {
  private static final String KNOWLEDGE_OBJECT = 'Knowledge__kav';

  /**
   * @description Searches Salesforce Knowledge articles using SOSL
   * @param searchQuery The search query string
   * @param maxResults Maximum number of results to return
   * @param pageNumber Page number for pagination (not used in SOSL, but kept for consistency)
   * @return List<UnifiedArticle> List of unified articles from Salesforce Knowledge
   */
  public static List<UnifiedArticle> searchArticles(
    String searchQuery,
    Integer maxResults,
    Integer pageNumber
  ) {
    List<UnifiedArticle> articles = new List<UnifiedArticle>();

    if (String.isBlank(searchQuery)) {
      return articles;
    }

    try {
      // Use SOSL for full-text search across Knowledge articles
      // Search in Title, Summary, and Body fields
      String soslQuery =
        'FIND {' +
        String.escapeSingleQuotes(searchQuery) +
        '} IN ALL FIELDS RETURNING ' +
        KNOWLEDGE_OBJECT +
        '(Id, Title, Summary, ArticleBody__c, UrlName, PublishStatus, ' +
        'CreatedDate, LastModifiedDate, CreatedBy.Name, Language, ' +
        'FirstPublishedDate, LastPublishedDate, ' +
        'KnowledgeArticleId, VersionNumber WHERE PublishStatus = \'Online\' ' +
        'AND IsLatestVersion = true) LIMIT ' +
        maxResults;

      List<List<SObject>> searchResults = Search.query(soslQuery);

      if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
        List<SObject> knowledgeArticles = searchResults[0];

        for (SObject ka : knowledgeArticles) {
          UnifiedArticle article = mapKnowledgeArticleToUnified(ka);
          if (article != null) {
            articles.add(article);
          }
        }
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error searching Salesforce Knowledge: ' + e.getMessage()
      );
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
    }

    return articles;
  }

  /**
   * @description Retrieves a specific Knowledge article by ID
   * @param articleId The Knowledge article ID (can be KnowledgeArticleId or Id)
   * @return UnifiedArticle The article, or null if not found
   */
  public static UnifiedArticle getArticleById(String articleId) {
    UnifiedArticle article = null;

    try {
      // Use dynamic SOQL to query Knowledge articles
      // Escape the articleId to prevent SOQL injection
      String escapedArticleId = String.escapeSingleQuotes(articleId);
      String soqlQuery =
        'SELECT Id, Title, Summary, ArticleBody__c, UrlName, PublishStatus, ' +
        'CreatedDate, LastModifiedDate, CreatedBy.Name, Language, ' +
        'FirstPublishedDate, LastPublishedDate, KnowledgeArticleId, VersionNumber ' +
        'FROM ' +
        KNOWLEDGE_OBJECT +
        ' WHERE (Id = \'' +
        escapedArticleId +
        '\' OR KnowledgeArticleId = \'' +
        escapedArticleId +
        '\') ' +
        'AND PublishStatus = \'Online\' AND IsLatestVersion = true ' +
        'WITH SECURITY_ENFORCED LIMIT 1';

      List<SObject> articles = Database.query(soqlQuery);

      if (!articles.isEmpty()) {
        article = mapKnowledgeArticleToUnified(articles[0]);
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error retrieving Salesforce Knowledge article: ' + e.getMessage()
      );
    }

    return article;
  }

  /**
   * @description Maps a Salesforce Knowledge article to UnifiedArticle
   * @param ka The Knowledge article (SObject)
   * @return UnifiedArticle The unified article representation
   */
  private static UnifiedArticle mapKnowledgeArticleToUnified(SObject ka) {
    UnifiedArticle article = new UnifiedArticle();
    article.source = 'Salesforce';

    try {
      // Map ID
      article.id = String.valueOf(ka.get('Id'));
      if (ka.get('KnowledgeArticleId') != null) {
        article.metadata.put('KnowledgeArticleId', String.valueOf(ka.get('KnowledgeArticleId')));
      }
      if (ka.get('VersionNumber') != null) {
        article.metadata.put('VersionNumber', String.valueOf(ka.get('VersionNumber')));
      }

      // Map title
      article.title = String.valueOf(ka.get('Title'));

      // Map content (ArticleBody__c can be Rich Text)
      if (ka.get('ArticleBody__c') != null) {
        article.content = String.valueOf(ka.get('ArticleBody__c'));
      }

      // Map snippet (Summary)
      if (ka.get('Summary') != null) {
        article.snippet = String.valueOf(ka.get('Summary'));
      }

      // Build URL - Knowledge articles use UrlName
      if (ka.get('UrlName') != null && String.isNotBlank(String.valueOf(ka.get('UrlName')))) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String knowledgeArticleId = String.valueOf(ka.get('KnowledgeArticleId'));
        String urlName = String.valueOf(ka.get('UrlName'));
        article.url = baseUrl + '/articles/Knowledge/' + knowledgeArticleId + '/' + urlName;
      }

      // Map dates
      if (ka.get('FirstPublishedDate') != null) {
        article.publishedDate = (DateTime) ka.get('FirstPublishedDate');
      } else if (ka.get('CreatedDate') != null) {
        article.publishedDate = (DateTime) ka.get('CreatedDate');
      }
      
      if (ka.get('LastModifiedDate') != null) {
        article.lastModifiedDate = (DateTime) ka.get('LastModifiedDate');
      }

      // Map author (CreatedBy is a relationship, need to get the Name field)
      if (ka.getSObject('CreatedBy') != null) {
        SObject createdBy = ka.getSObject('CreatedBy');
        if (createdBy.get('Name') != null) {
          article.authorName = String.valueOf(createdBy.get('Name'));
        }
      }

      // Map language
      if (ka.get('Language') != null) {
        article.language = String.valueOf(ka.get('Language'));
      }

      // Map article type
      article.articleType = 'Knowledge';

      // Note: Salesforce Knowledge uses Data Categories for categorization
      // These would need to be queried separately if needed
      // Tags are typically not available on standard Knowledge objects

    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error mapping Salesforce Knowledge article: ' + e.getMessage()
      );
      return null;
    }

    return article;
  }

  /**
   * @description Gets all available tags/categories from Knowledge articles
   * This is a placeholder - actual implementation depends on Data Categories setup
   * @return List<String> List of available categories
   */
  public static List<String> getAvailableCategories() {
    // This would require querying Data Category Groups
    // For now, return empty list - can be extended based on org setup
    return new List<String>();
  }
}

