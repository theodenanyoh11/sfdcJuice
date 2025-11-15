/**
 * @description Request DTO for unified search operations
 * @author sfdcJuice
 */
public class UnifiedSearchRequest {
  @AuraEnabled
  public String searchQuery { get; set; }

  @AuraEnabled
  public String sourceFilter { get; set; } // 'All', 'Helpjuice', 'Salesforce'

  @AuraEnabled
  public List<String> tagFilters { get; set; }

  @AuraEnabled
  public List<String> categoryFilters { get; set; }

  @AuraEnabled
  public DateTime dateFrom { get; set; }

  @AuraEnabled
  public DateTime dateTo { get; set; }

  @AuraEnabled
  public Integer maxResults { get; set; }

  @AuraEnabled
  public Integer pageNumber { get; set; }

  public UnifiedSearchRequest() {
    this.sourceFilter = 'All';
    this.tagFilters = new List<String>();
    this.categoryFilters = new List<String>();
    this.maxResults = 25;
    this.pageNumber = 1;
  }
}

