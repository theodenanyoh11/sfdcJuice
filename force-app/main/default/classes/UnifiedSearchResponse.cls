/**
 * @description Response DTO for unified search operations
 * @author sfdcJuice
 */
public class UnifiedSearchResponse {
  @AuraEnabled
  public List<UnifiedArticle> articles { get; set; }

  @AuraEnabled
  public Integer totalCount { get; set; }

  @AuraEnabled
  public Integer pageNumber { get; set; }

  @AuraEnabled
  public Integer totalPages { get; set; }

  @AuraEnabled
  public Boolean hasMore { get; set; }

  @AuraEnabled
  public String errorMessage { get; set; }

  @AuraEnabled
  public Boolean hasError { get; set; }

  public UnifiedSearchResponse() {
    this.articles = new List<UnifiedArticle>();
    this.hasError = false;
  }
}

