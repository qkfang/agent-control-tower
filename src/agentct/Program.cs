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

app.UseDefaultFiles();
app.UseStaticFiles();

app.MapHealthChecks("/health");

app.MapGet("/", () => Results.Redirect("/index.html"));

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

var researchAgent = new CtAgResearch(
    aiProjectClient,
    deploymentName,
    [apiIntgTool, webSearchTool],
    loggerFactory.CreateLogger<CtAgResearch>()
);
var suggestionAgent = new CtAgSuggestion(aiProjectClient, deploymentName, [apiIntgTool], loggerFactory.CreateLogger<CtAgSuggestion>());
var insightAgent = new CtAgInsight(aiProjectClient, deploymentName, [apiIntgTool], loggerFactory.CreateLogger<CtAgInsight>());
var traderAgent = new CtAgTrader(aiProjectClient, deploymentName, [tradingTool], loggerFactory.CreateLogger<CtAgTrader>());
var ingestionAgent = new CtAgIngestion(aiProjectClient, deploymentName, loggerFactory.CreateLogger<CtAgIngestion>());
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
