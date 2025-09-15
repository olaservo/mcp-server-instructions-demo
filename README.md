# MCP Server Instructions Demo

A minimal TypeScript Express API for evaluating the addition of server `instructions` in the GitHub MCP Server.

## Evaluation setup

1. Built a version of the GitHub MCP Server which includes server instructions as well as a flag to disable them: https://github.com/olaservo/github-mcp-server/tree/add-server-instructions
2. Configured 2 separate instances of the locally built MCP server in VSCode (see below for full config), one with instructions disabled.
3. For each scenario, I only enabled the tools from a single instance of the GitHub server.  I also verified in the GitHub Copilot chat logs that the instructions were either loaded or not loaded (depending on the scenario I was testing)
4. For each generation, I used the exact same code changes in the PR. I used a script to recreate the branch and PR in the cases that the model left any comments on the PR, so I would always start from a clean slate.
5. After each initial prompt and results, I used the "Export Chat" function to export a full transcript of the chat.  Example transcripts are in the `evals\transcripts` folder.

### VSCode MCP Server Configuration

```
		"github-with-instructions": {
			"command": "C:\\path\\to\\github-mcp-server.exe",
			"args": ["stdio", "--toolsets", "context,pull_requests"],
			"env": {
				"GITHUB_PERSONAL_ACCESS_TOKEN": "${input:github_token}"
			}
		},
		"github-without-instructions": {
			"command": "C:\\path\\to\\github-mcp-server.exe",
			"args": ["stdio", "--toolsets", "context,pull_requests"],
			"env": {
				"GITHUB_PERSONAL_ACCESS_TOKEN": "${input:github_token}",
				"DISABLE_INSTRUCTIONS": "true"
			}
		}
```