/**
 * @description DTO for Helpjuice Category
 * @author sfdcJuice
 */
public class HelpjuiceCategory {
  @AuraEnabled
  public String id { get; set; }

  @AuraEnabled
  public String name { get; set; }

  @AuraEnabled
  public String url { get; set; }

  @AuraEnabled
  public String description { get; set; }

  @AuraEnabled
  public DateTime createdAt { get; set; }

  @AuraEnabled
  public DateTime updatedAt { get; set; }
}

