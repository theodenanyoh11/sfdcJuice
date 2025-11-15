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
        List<Knowledge__kav> knowledgeArticles = (List<Knowledge__kav>) searchResults[0];

        for (Knowledge__kav ka : knowledgeArticles) {
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
      List<Knowledge__kav> articles = [
        SELECT
          Id,
          Title,
          Summary,
          ArticleBody__c,
          UrlName,
          PublishStatus,
          CreatedDate,
          LastModifiedDate,
          CreatedBy.Name,
          Language,
          FirstPublishedDate,
          LastPublishedDate,
          KnowledgeArticleId,
          VersionNumber
        FROM Knowledge__kav
        WHERE
          (Id = :articleId OR KnowledgeArticleId = :articleId)
          AND PublishStatus = 'Online'
          AND IsLatestVersion = true
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];

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
   * @param ka The Knowledge article
   * @return UnifiedArticle The unified article representation
   */
  private static UnifiedArticle mapKnowledgeArticleToUnified(
    Knowledge__kav ka
  ) {
    UnifiedArticle article = new UnifiedArticle();
    article.source = 'Salesforce';

    try {
      // Map ID
      article.id = ka.Id;
      article.metadata.put('KnowledgeArticleId', ka.KnowledgeArticleId);
      article.metadata.put('VersionNumber', ka.VersionNumber);

      // Map title
      article.title = ka.Title;

      // Map content (ArticleBody__c can be Rich Text)
      article.content = ka.ArticleBody__c;

      // Map snippet (Summary)
      article.snippet = ka.Summary;

      // Build URL - Knowledge articles use UrlName
      if (String.isNotBlank(ka.UrlName)) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        article.url =
          baseUrl +
          '/articles/Knowledge/' +
          ka.KnowledgeArticleId +
          '/' +
          ka.UrlName;
      }

      // Map dates
      article.publishedDate = ka.FirstPublishedDate != null
        ? ka.FirstPublishedDate
        : ka.CreatedDate;
      article.lastModifiedDate = ka.LastModifiedDate;

      // Map author
      if (ka.CreatedBy != null) {
        article.authorName = ka.CreatedBy.Name;
      }

      // Map language
      article.language = ka.Language;

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

