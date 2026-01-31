import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  GetPromptRequestSchema,
  ListPromptsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { getRootFromEnv } from "./fs-utils.js";
import { listPrompts, getPromptContent, formatPromptError } from "./prompts.js";
import { listResources, readResource } from "./resources.js";

const server = new Server(
  { name: "personakit-mcp", version: "0.2.0" },
  { capabilities: { resources: {}, prompts: {} } }
);

server.setRequestHandler(ListResourcesRequestSchema, async () => {
  const root = getRootFromEnv();
  const resources = await listResources(root);
  return {
    resources: resources.map((resource) => ({
      uri: resource.uri,
      name: resource.name,
    })),
  };
});

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const root = getRootFromEnv();
  const uri = request.params.uri;
  const { text, mimeType } = await readResource(root, uri);
  return {
    contents: [
      {
        uri,
        mimeType,
        text,
      },
    ],
  };
});

server.setRequestHandler(ListPromptsRequestSchema, async () => {
  return { prompts: listPrompts() };
});

server.setRequestHandler(GetPromptRequestSchema, async (request) => {
  const params = request.params as Record<string, unknown> | undefined;
  const promptId =
    (typeof params?.name === "string" && params.name) ||
    (typeof params?.id === "string" && params.id) ||
    (typeof params?.promptId === "string" && params.promptId);

  if (!promptId) {
    throw new Error("Prompt id is required.");
  }

  const argsValue = params?.arguments ?? params?.args;
  const args =
    argsValue && typeof argsValue === "object" && !Array.isArray(argsValue)
      ? (argsValue as Record<string, unknown>)
      : {};

  try {
    const root = getRootFromEnv();
    const text = await getPromptContent(root, promptId, args);
    return {
      messages: [
        {
          role: "user",
          content: {
            type: "text",
            text,
          },
        },
      ],
    };
  } catch (error) {
    const message = formatPromptError(error);
    throw new Error(message);
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
