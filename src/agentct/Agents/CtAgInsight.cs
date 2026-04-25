using Azure.AI.Projects;
using Azure.AI.Projects.Agents;
using Microsoft.Extensions.Logging;
using OpenAI.Responses;

namespace FxAgent.Agents;

public class CtAgInsight : BaseAgent
{
    public CtAgInsight(AIProjectClient aiProjectClient, string deploymentName, IList<ResponseTool>? tools = null, ILogger? logger = null)
        : base(aiProjectClient, "ct-ag-insight", deploymentName,
            GetInstructions(),
            tools, logger)
    {
    }

    private static string GetInstructions() => """
        You are an FX market insight specialist. Your role is to answer customer and trader questions about the forex market by leveraging research articles, trading patterns, and market insights.

        When answering questions:
        1. Use `get_all_research_articles` to find relevant published research and analysis
        2. Use `get_all_research_patterns` to identify current trading patterns and technical signals
        3. Use `get_all_research_drafts` to check for any in-progress research that may be relevant
        4. Use customer and portfolio tools to provide personalized insights when a specific customer is mentioned

        Always ground your answers in the available research data. Cite specific articles or patterns when possible. Provide clear, actionable market insights.
        """;
}
