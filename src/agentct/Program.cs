using Azure.AI.Projects;
using Azure.AI.Projects.Agents;
using Azure.Identity;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using FxAgent.Agents;
using OpenAI.Responses;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenTelemetry().UseAzureMonitor();

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHealthChecks();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapHealthChecks("/health");

app.MapGet("/", () => Results.Redirect("/swagger"));

var logger = app.Services.GetRequiredService<ILogger<Program>>();

var endpoint = app.Configuration["AZURE_AI_PROJECT_ENDPOINT"]
    ?? throw new InvalidOperationException("AZURE_AI_PROJECT_ENDPOINT is not set.");
var deploymentName = app.Configuration["AZURE_AI_MODEL_DEPLOYMENT_NAME"]
    ?? throw new InvalidOperationException("AZURE_AI_MODEL_DEPLOYMENT_NAME is not set.");
var webSearchTool = ResponseTool.CreateWebSearchTool();

var tenantId = app.Configuration["AZURE_TENANT_ID"];
var defaultCredential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
{
    TenantId = tenantId
});

AIProjectClient aiProjectClient = new(new Uri(endpoint), defaultCredential);

var apiMcpUrl = app.Configuration["API_INTG_MCP_URL"];
var tradingMcpUrl = app.Configuration["TRADING_PLATFORM_MCP_URL"];

var apiIntgTool = ResponseTool.CreateMcpTool(
    serverLabel: "api-intg",
    serverUri: new Uri($"{apiMcpUrl}/mcp"),
    toolCallApprovalPolicy: new McpToolCallApprovalPolicy(GlobalMcpToolCallApprovalPolicy.NeverRequireApproval)
);

var tradingTool = ResponseTool.CreateMcpTool(
    serverLabel: "trading-platform",
    serverUri: new Uri($"{tradingMcpUrl}/mcp"),
    toolCallApprovalPolicy: new McpToolCallApprovalPolicy(GlobalMcpToolCallApprovalPolicy.NeverRequireApproval)
);

var loggerFactory = app.Services.GetRequiredService<ILoggerFactory>();

// Configure Fabric data agent tool for FxAgInsight
var fabricConnectionName = app.Configuration["FABRIC_CONNECTION_NAME"];
Action<DeclarativeAgentDefinition>? insightFabricConfig = null;
if (!string.IsNullOrEmpty(fabricConnectionName))
{
    var fabricConnection = aiProjectClient.Connections.GetConnection(fabricConnectionName);
    var fabricToolOption = new FabricDataAgentToolOptions
    {
        ProjectConnections = { new ToolProjectConnection(projectConnectionId: fabricConnection.Id) }
    };
    insightFabricConfig = agentDef => agentDef.Tools.Add(new MicrosoftFabricPreviewTool(fabricToolOption));
    logger.LogInformation("Fabric data agent tool configured for FxAgInsight with connection: {ConnectionName}", fabricConnectionName);
}
else
{
    logger.LogWarning("FABRIC_CONNECTION_NAME is not set. FxAgInsight will run without Fabric data agent.");
}

var researchAgent = new FxAgResearch(
    aiProjectClient,
    deploymentName,
    [apiIntgTool, webSearchTool],
    loggerFactory.CreateLogger<FxAgResearch>()
);
var suggestionAgent = new FxAgSuggestion(aiProjectClient, deploymentName, [apiIntgTool], loggerFactory.CreateLogger<FxAgSuggestion>());
var insightAgent = new FxAgInsight(aiProjectClient, deploymentName, [apiIntgTool], insightFabricConfig, loggerFactory.CreateLogger<FxAgInsight>());
var traderAgent = new FxAgTrader(aiProjectClient, deploymentName, [tradingTool], loggerFactory.CreateLogger<FxAgTrader>());
var ingestionAgent = new FxAgIngestion(aiProjectClient, loggerFactory.CreateLogger<FxAgIngestion>());
var supportAgent = new CtAgSupport(aiProjectClient, deploymentName, loggerFactory.CreateLogger<CtAgSupport>());
var docAgent = new CtAgDoc(aiProjectClient, deploymentName, loggerFactory.CreateLogger<CtAgDoc>());
var customerAgent = new CtAgCustomer(aiProjectClient, deploymentName, loggerFactory.CreateLogger<CtAgCustomer>());

app.MapPost("/research", async (ChatRequest request) =>
{
    logger.LogInformation("Research request: {Message}", request.Message);
    var response = await researchAgent.RunAsync(request.Message);
    return Results.Ok(new { response });
});

app.MapPost("/suggestion", async (ChatRequest request) =>
{
    logger.LogInformation("Suggestion request: {Message}", request.Message);
    var response = await suggestionAgent.RunAsync(request.Message);
    return Results.Ok(new { response });
});

app.MapPost("/trader", async (ChatRequest request) =>
{
    logger.LogInformation("Trader request: {Message}", request.Message);
    var response = await traderAgent.RunAsync(request.Message);
    return Results.Ok(new { response });
});

app.MapPost("/insight", async (ChatRequest request) =>
{
    logger.LogInformation("Insight request: {Message}", request.Message);
    var response = await insightAgent.RunAsync(request.Message);
    return Results.Ok(new { response });
});

app.MapPost("/ingestion", async (ChatRequest request) =>
{
    logger.LogInformation("Ingestion request: {Message}", request.Message);
    var response = await ingestionAgent.RunAsync(request.Message);
    return Results.Ok(new { response });
});

app.MapPost("/support", async (ChatRequest request) =>
{
    logger.LogInformation("Support request: {Message}", request.Message);
    var response = await supportAgent.RunAsync(request.Message);
    return Results.Ok(new { response });
});

app.MapPost("/doc", async (ChatRequest request) =>
{
    logger.LogInformation("Doc request: {Message}", request.Message);
    var response = await docAgent.RunAsync(request.Message);
    return Results.Ok(new { response });
});

app.MapPost("/customer", async (ChatRequest request) =>
{
    logger.LogInformation("Customer request: {Message}", request.Message);
    var response = await customerAgent.RunAsync(request.Message);
    return Results.Ok(new { response });
});

await app.RunAsync();

record ChatRequest(string Message);
