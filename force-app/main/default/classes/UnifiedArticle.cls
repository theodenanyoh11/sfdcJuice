/**
 * @description Unified Article DTO representing articles from both Helpjuice and Salesforce Knowledge
 * @author sfdcJuice
 */
public class UnifiedArticle {
  @AuraEnabled
  public String id { get; set; }

  @AuraEnabled
  public String title { get; set; }

  @AuraEnabled
  public String content { get; set; }

  @AuraEnabled
  public String snippet { get; set; }

  @AuraEnabled
  public String source { get; set; } // 'Helpjuice' or 'Salesforce'

  @AuraEnabled
  public String url { get; set; }

  @AuraEnabled
  public List<String> tags { get; set; }

  @AuraEnabled
  public List<String> categories { get; set; }

  @AuraEnabled
  public DateTime publishedDate { get; set; }

  @AuraEnabled
  public DateTime lastModifiedDate { get; set; }

  @AuraEnabled
  public String authorName { get; set; }

  @AuraEnabled
  public String articleType { get; set; }

  @AuraEnabled
  public String language { get; set; }

  @AuraEnabled
  public Integer viewCount { get; set; }

  @AuraEnabled
  public Integer upvoteCount { get; set; }

  @AuraEnabled
  public Map<String, Object> metadata { get; set; }

  public UnifiedArticle() {
    this.tags = new List<String>();
    this.categories = new List<String>();
    this.metadata = new Map<String, Object>();
  }
}

