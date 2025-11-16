/**
 * @description Tests for Unified DTO models (UnifiedArticle, UnifiedSearchRequest, UnifiedSearchResponse, HelpjuiceCategory)
 */
@isTest
private class UnifiedModelsTest {

  @isTest
  static void testUnifiedArticleDefaultsAndProperties() {
    UnifiedArticle article = new UnifiedArticle();
    System.assertNotEquals(null, article.tags, 'Tags list should be initialized');
    System.assertNotEquals(null, article.categories, 'Categories list should be initialized');
    System.assertNotEquals(null, article.metadata, 'Metadata map should be initialized');

    article.id = 'A1';
    article.title = 'Sample Title';
    article.content = 'Body';
    article.snippet = 'Snippet';
    article.source = 'Helpjuice';
    article.url = 'https://example.com/a1';
    article.tags.add('tag1');
    article.categories.add('cat1');

    System.assertEquals('A1', article.id);
    System.assertEquals('Sample Title', article.title);
    System.assertEquals('Helpjuice', article.source);
    System.assertEquals(1, article.tags.size());
    System.assertEquals(1, article.categories.size());
  }

  @isTest
  static void testUnifiedSearchRequestDefaults() {
    UnifiedSearchRequest request = new UnifiedSearchRequest();
    System.assertEquals('All', request.sourceFilter);
    System.assertEquals(25, request.maxResults);
    System.assertEquals(1, request.pageNumber);
    System.assertNotEquals(null, request.tagFilters);
    System.assertNotEquals(null, request.categoryFilters);
  }

  @isTest
  static void testUnifiedSearchResponseDefaults() {
    UnifiedSearchResponse response = new UnifiedSearchResponse();
    System.assertNotEquals(null, response.articles);
    System.assertEquals(false, response.hasError);
  }

  @isTest
  static void testHelpjuiceCategoryProperties() {
    HelpjuiceCategory cat = new HelpjuiceCategory();
    cat.id = '10';
    cat.name = 'Category';
    cat.url = 'https://example.com/cat';
    cat.description = 'Description';

    System.assertEquals('10', cat.id);
    System.assertEquals('Category', cat.name);
    System.assertEquals('https://example.com/cat', cat.url);
  }
}


