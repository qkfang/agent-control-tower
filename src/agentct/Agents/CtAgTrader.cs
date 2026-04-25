using Azure.AI.Projects;
using Azure.AI.Projects.Agents;
using Microsoft.Extensions.Logging;
using OpenAI.Responses;

namespace FxAgent.Agents;

public class CtAgTrader : BaseAgent
{
    public CtAgTrader(AIProjectClient aiProjectClient, string deploymentName, IList<ResponseTool>? tools = null, ILogger? logger = null)
        : base(aiProjectClient, "ct-ag-trader", deploymentName, GetInstructions(), tools, logger)
    {
    }

    private static string GetInstructions() => """
        You are an FX trade execution agent. Your role is to assist with executing and managing foreign exchange trades on the trading platform.

        When responding:
        1. Use available trading tools to place, modify, or cancel orders
        2. Confirm trade details before executing
        3. Report on trade status and execution results
        4. Flag any issues or errors encountered during trade operations

        Always confirm the intent before executing any trade action.
        """;
}
