/**
 * @description Test class for UnifiedSearchService and related services
 * @author sfdcJuice
 */
@isTest
private class UnifiedSearchServiceTest {
  @testSetup
  static void setup() {
    // Create test Custom Metadata record would require actual metadata deployment
    // For testing, we'll mock the configuration service
  }

  @isTest
  static void testUnifiedSearchRequestCreation() {
    UnifiedSearchRequest request = new UnifiedSearchRequest();
    request.searchQuery = 'test query';
    request.sourceFilter = 'All';
    request.maxResults = 10;

    System.assertEquals('test query', request.searchQuery);
    System.assertEquals('All', request.sourceFilter);
    System.assertEquals(10, request.maxResults);
  }

  @isTest
  static void testUnifiedSearchResponseCreation() {
    UnifiedSearchResponse response = new UnifiedSearchResponse();
    response.articles = new List<UnifiedArticle>();
    response.totalCount = 0;
    response.hasError = false;

    System.assertEquals(0, response.articles.size());
    System.assertEquals(false, response.hasError);
  }

  @isTest
  static void testUnifiedArticleCreation() {
    UnifiedArticle article = new UnifiedArticle();
    article.id = '123';
    article.title = 'Test Article';
    article.source = 'Helpjuice';
    article.tags = new List<String>{ 'tag1', 'tag2' };

    System.assertEquals('123', article.id);
    System.assertEquals('Test Article', article.title);
    System.assertEquals('Helpjuice', article.source);
    System.assertEquals(2, article.tags.size());
  }

  @isTest
  static void testConfigServiceWithNoConfig() {
    // This test verifies the service handles missing config gracefully
    sfdcJuice_Config__mdt config = sfdcJuiceConfigService.getActiveConfig();
    // In a real test org, you would create Custom Metadata records
    // For now, we're just testing the method doesn't throw exceptions
    System.assert(true, 'Config service should not throw exceptions');
  }

  @isTest
  static void testUnifiedSearchServiceWithInvalidRequest() {
    UnifiedSearchRequest request = new UnifiedSearchRequest();
    request.searchQuery = ''; // Empty query

    Test.startTest();
    UnifiedSearchResponse response = UnifiedSearchService.search(request);
    Test.stopTest();

    System.assert(response.hasError, 'Should return error for empty query');
    System.assertNotEquals(null, response.errorMessage);
  }

  @isTest
  static void testUnifiedSearchServiceGetArticleWithUnknownSource() {
    Test.startTest();
    UnifiedArticle article = UnifiedSearchService.getArticle('123', 'UnknownSource');
    Test.stopTest();

    System.assertEquals(null, article, 'Unknown source should return null');
  }

  @isTest
  static void testUnifiedSearchServiceWithWhitespaceQuery() {
    UnifiedSearchRequest request = new UnifiedSearchRequest();
    request.searchQuery = '   '; // whitespace only

    UnifiedSearchResponse response = UnifiedSearchService.search(request);
    System.assertEquals(true, response.hasError);
    System.assertEquals(true, String.isNotBlank(response.errorMessage));
  }

  @isTest
  static void testSalesforceKnowledgeServiceSearch() {
    // Note: This test requires Knowledge articles in the org
    // In a real scenario, you would create test Knowledge articles
    Test.startTest();
    List<UnifiedArticle> articles = SalesforceKnowledgeService.searchArticles(
      'test',
      10,
      1
    );
    Test.stopTest();

    // Should not throw exception even if no articles found
    System.assertNotEquals(null, articles);
  }

  @isTest
  static void testGetArticleWithInvalidParams() {
    Test.startTest();
    UnifiedArticle article = UnifiedSearchService.getArticle('', '');
    Test.stopTest();

    System.assertEquals(null, article, 'Should return null for invalid params');
  }
}

