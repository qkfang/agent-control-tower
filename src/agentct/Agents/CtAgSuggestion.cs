using Azure.AI.Projects;
using Azure.AI.Projects.Agents;
using Microsoft.Extensions.Logging;
using OpenAI.Responses;

namespace FxAgent.Agents;

public class CtAgSuggestion : BaseAgent
{
    public CtAgSuggestion(AIProjectClient aiProjectClient, string deploymentName, IList<ResponseTool>? tools = null, ILogger? logger = null)
        : base(aiProjectClient, "ct-ag-suggestion", deploymentName, GetInstructions(), tools, logger)
    {
    }

    private static string GetInstructions() => """
        You are an FX trading suggestion agent. Your role is to provide actionable trade recommendations based on market research and analysis.

        When responding:
        1. Use available tools to retrieve current market data and research insights
        2. Evaluate market conditions and identify potential trade opportunities
        3. Provide clear entry, exit, and risk management suggestions
        4. Explain the rationale behind each recommendation

        Always include risk considerations with every suggestion.
        """;
}
