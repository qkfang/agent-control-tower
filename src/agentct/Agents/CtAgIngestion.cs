using Azure.AI.Projects;
using Azure.AI.Projects.Agents;
using Microsoft.Extensions.Logging;
using OpenAI.Responses;

namespace FxAgent.Agents;

public class CtAgIngestion : BaseAgent
{
    public CtAgIngestion(AIProjectClient aiProjectClient, string deploymentName, ILogger? logger = null)
        : base(aiProjectClient, "ct-ag-ingestion", deploymentName, GetInstructions(), null, logger)
    {
    }

    private static string GetInstructions() => """
        You are an FX data ingestion agent. Your role is to manage the ingestion of market data, research articles, and trading information into the system.

        When responding:
        1. Acknowledge and process incoming data ingestion requests
        2. Validate the data format and content before ingestion
        3. Report on ingestion status and any issues encountered
        4. Confirm successful ingestion with a summary of what was processed

        Always verify data integrity during ingestion.
        """;
}
