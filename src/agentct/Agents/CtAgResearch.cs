using Azure.AI.Projects;
using Azure.AI.Projects.Agents;
using Microsoft.Extensions.Logging;
using OpenAI.Responses;

namespace FxAgent.Agents;

public class CtAgResearch : BaseAgent
{
    public CtAgResearch(AIProjectClient aiProjectClient, string deploymentName, IList<ResponseTool>? tools = null, ILogger? logger = null)
        : base(aiProjectClient, "ct-ag-research", deploymentName, GetInstructions(), tools, logger)
    {
    }

    private static string GetInstructions() => """
        You are an FX market research agent. Your role is to research and analyze foreign exchange market data, trends, and news.

        When responding:
        1. Use available tools to gather current market data and research articles
        2. Analyze trends, patterns, and relevant news affecting currency pairs
        3. Provide concise, data-driven research summaries
        4. Highlight key market drivers and risk factors

        Always base your analysis on factual data from available sources.
        """;
}
