using CapstoneWebApp;
using Microsoft.Azure.Cosmos;
using System.ComponentModel;
using Microsoft.Extensions.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);

// 1. Connection Setup
// Replace with your connection string from Key Vault/Environment Variables
string connectionString = builder.Configuration["COSMOS_CONN"];
string databaseId = "database";
string containerId = "quotes-container";

CosmosClient client = new CosmosClient(connectionString);
Microsoft.Azure.Cosmos.Container container = client.GetContainer(databaseId, containerId);

// Register Cosmos client and container in DI so health checks can use them
builder.Services.AddSingleton(client);
builder.Services.AddSingleton(container);

// Register health checks and add the Cosmos DB check
builder.Services.AddHealthChecks()
    .AddCheck<CosmosHealthCheck>("cosmos_db");

var app = builder.Build();

// Health endpoint
app.MapHealthChecks("/health");

app.MapGet("/", async () =>
{
    var quotes = new List<QuoteItem>();

    // 2. Read All Quotes
    // Using a SQL query to fetch all documents
    using FeedIterator<QuoteItem> feed = container.GetItemQueryIterator<QuoteItem>("SELECT * FROM c");

    while (feed.HasMoreResults)
    {
        FeedResponse<QuoteItem> response = await feed.ReadNextAsync();
        quotes.AddRange(response);
    }

    if (!quotes.Any()) return Results.Content("<h1>No quotes found in database.</h1>", "text/html");

    // 3. Randomly Select One
    var random = new Random();
    var randomQuote = quotes[random.Next(quotes.Count)];

    // 4. Display as HTML
    string htmlOutput = $@"
        <html>
            <body style='font-family: sans-serif; text-align: center; padding-top: 50px;'>
                <div style='max-width: 600px; margin: auto; border: 1px solid #ddd; padding: 20px; border-radius: 10px;'>
                    <h1 style='color: #333;'>""{randomQuote.quote}""</h1>
                    <p style='font-style: italic; color: #666;'>— {randomQuote.author}</p>
                    <button style='background-color: red; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer;' onclick='window.location.reload()'>
                        Get Another Quote
                    </button>
                </div>
            </body>
        </html>";

    return Results.Content(htmlOutput, "text/html");
});

app.Run();