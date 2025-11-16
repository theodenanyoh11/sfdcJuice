/**
 * @description Test class for HelpjuiceApiService using HttpCalloutMock and test Custom Metadata config
 */
@isTest
private class HelpjuiceApiServiceTest {

  /**
   * Simple HttpCalloutMock implementation that returns different payloads
   * based on the requested endpoint.
   */
  private class HelpjuiceApiHttpMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      String endpoint = req.getEndpoint();

      // Default values
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');

      if (endpoint.contains('/api/v3/search')) {
        // Minimal valid search response with one result
        String body =
          '{"searches":[{' +
          '"id":123,' +
          '"name":"Test Search Article",' +
          '"answer_sample":"Short answer",' +
          '"long_answer_sample":"Long answer body",' +
          '"url":"https://example.helpjuice.com/test-article",' +
          '"tag_names":["tag1","tag2"],' +
          '"categories":{"current":{"name":"Getting Started"}},' +
          '"updated_at":"2024-05-01T12:00:00.000Z",' +
          '"created_at":"2024-04-01T10:00:00.000Z",' +
          '"last_published_date":"May 3rd, 2024",' +
          '"last_published_user_name":"Author Name",' +
          '"is_published":true,' +
          '"is_internal":false,' +
          '"is_private":false,' +
          '"slug":"test-article"' +
          '}]}';
        res.setBody(body);
      } else if (endpoint.contains('/api/v3/articles?')) {
        // Popular articles list
        String body =
          '{"articles":[{' +
          '"id":1,' +
          '"name":"Popular Article 1",' +
          '"views":10,' +
          '"answer":[{"processed_body":"<p>Body 1</p>","body_txt":"Body 1 text"}]' +
          '},{' +
          '"id":2,' +
          '"name":"Popular Article 2",' +
          '"views":20,' +
          '"answer":[{"processed_body":"<p>Body 2</p>","body_txt":"Body 2 text"}]' +
          '}]}';
        res.setBody(body);
      } else if (endpoint.contains('/api/v3/articles/')) {
        // Single article response
        String body =
          '{"article":{' +
          '"id":999,' +
          '"name":"Single Article",' +
          '"answer":[{"processed_body":"<p>Full article body</p>","body_txt":"Full article"}],' +
          '"keywords":[{"name":"k1"},{"name":"k2"}],' +
          '"categories":[{"name":"Cat 1"}],' +
          '"created_at":"2024-01-01T09:00:00.000Z",' +
          '"updated_at":"2024-02-01T09:00:00.000Z",' +
          '"views":5,' +
          '"upvotes_count":2,' +
          '"language":"en",' +
          '"author":{"name":"Article Author"},' +
          '"slug":"single-article"' +
          '}}';
        res.setBody(body);
      } else if (endpoint.contains('/api/v3/categories')) {
        // Categories response
        String body =
          '{"categories":[{' +
          '"id":10,' +
          '"name":"Category 1",' +
          '"url":"https://example.helpjuice.com/cat-1",' +
          '"description":"First category",' +
          '"created_at":"2023-01-01T00:00:00.000Z",' +
          '"updated_at":"2023-02-01T00:00:00.000Z"' +
          '}]}';
        res.setBody(body);
      } else {
        // Unexpected endpoint – return generic success with empty body
        res.setBody('{}');
      }

      return res;
    }
  }

  @testSetup
  static void setupConfig() {
    // Create a test Custom Metadata config record.
    // Using unique DeveloperName to avoid conflicts with any existing metadata.
    sfdcJuice_Config__mdt testConfig = new sfdcJuice_Config__mdt(
      DeveloperName = 'Test_Config',
      MasterLabel = 'Test Config',
      Helpjuice_API_Key__c = 'TEST_API_KEY',
      Helpjuice_Base_URL__c = 'https://example.helpjuice.com',
      Is_Active__c = true,
      Max_Results_Per_Source__c = 25,
      Request_Timeout_Seconds__c = 30
    );
    insert testConfig;
  }

  @isTest
  static void testSearchArticlesShortQueryReturnsEmpty() {
    // Queries shorter than 3 characters should return empty list without callout
    List<UnifiedArticle> articles = HelpjuiceApiService.searchArticles('ab', 10, 1);
    System.assertEquals(0, articles.size(), 'Short query should return no results');
  }

  @isTest
  static void testSearchArticlesSuccessWithMock() {
    Test.setMock(HttpCalloutMock.class, new HelpjuiceApiHttpMock());

    Test.startTest();
    List<UnifiedArticle> articles = HelpjuiceApiService.searchArticles('test search', 10, 1);
    Test.stopTest();

    System.assertNotEquals(null, articles, 'Articles list should not be null');
    System.assertEquals(1, articles.size(), 'Expected one article from mock search response');
    UnifiedArticle art = articles[0];
    System.assertEquals('Helpjuice', art.source);
    System.assertEquals('Test Search Article', art.title);
    System.assertEquals('https://example.helpjuice.com/test-article', art.url);
    System.assertEquals(true, art.tags != null && art.tags.size() > 0, 'Tags should be populated');
  }

  @isTest
  static void testGetArticleByIdSuccessWithMock() {
    Test.setMock(HttpCalloutMock.class, new HelpjuiceApiHttpMock());

    Test.startTest();
    UnifiedArticle article = HelpjuiceApiService.getArticleById('999');
    Test.stopTest();

    System.assertNotEquals(null, article, 'Article should not be null');
    System.assertEquals('Single Article', article.title);
    System.assertEquals('Helpjuice', article.source);
    System.assertEquals('Article Author', article.authorName);
    System.assertEquals('en', article.language);
    System.assertEquals(true, article.viewCount > 0, 'View count should be set from mock');
  }

  @isTest
  static void testGetPopularArticlesUsesViewsSorting() {
    Test.setMock(HttpCalloutMock.class, new HelpjuiceApiHttpMock());

    Test.startTest();
    List<UnifiedArticle> popular = HelpjuiceApiService.getPopularArticles(5);
    Test.stopTest();

    System.assertEquals(2, popular.size(), 'Mock returns two popular articles');
    System.assertEquals(true, popular[0].viewCount >= popular[1].viewCount, 'Articles should be sorted by views descending');
  }

  @isTest
  static void testGetCategoriesReturnsCategories() {
    Test.setMock(HttpCalloutMock.class, new HelpjuiceApiHttpMock());

    Test.startTest();
    List<HelpjuiceCategory> categories = HelpjuiceApiService.getCategories();
    Test.stopTest();

    System.assertNotEquals(null, categories);
    System.assertEquals(1, categories.size(), 'Expected one category from mock response');
    System.assertEquals('Category 1', categories[0].name);
  }
}


