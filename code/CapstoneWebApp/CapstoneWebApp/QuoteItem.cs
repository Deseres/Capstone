namespace CapstoneWebApp;

public class QuoteItem
{
    [Newtonsoft.Json.JsonProperty("id")]
    public string id { get; set; }
    public string quote { get; set; }
    public string author { get; set; }
}
