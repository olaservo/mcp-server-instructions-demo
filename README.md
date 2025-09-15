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

### Example Results

To validate the impact of server instructions on PR reviews, I conducted a controlled evaluation in VSCode comparing model behavior with and without adding instructions in the GitHub MCP Server.  My hypothesis was that this would improve the consistency of workflows across models, while still ensuring that we're only loading relevant instructions for the tools we want to use.  Here is an example of what I added for if the `pull_requests` toolset is enabled:

```go
func GenerateInstructions(enabledToolsets []string) string {
    var instructions []string
    
    // Universal context management - always present
    baseInstruction := "GitHub API responses can overflow context windows. Strategy: 1) Always prefer 'search_*' tools over 'list_*' tools when possible, 2) Process large datasets in batches of 5-10 items, 3) For summarization tasks, fetch minimal data first, then drill down into specifics."
    
    // Toolset-specific instructions
    if contains(enabledToolsets, "pull_requests") {
        instructions = append(instructions, "PR review workflow: Always use 'create_pending_pull_request_review' → 'add_comment_to_pending_review' → 'submit_pending_pull_request_review' for complex reviews with line-specific comments.")
    }
    
    return strings.Join(append([]string{baseInstruction}, instructions...), " ")
}
```

Using 40 GitHub PR review sessions on the same set of code changes, I measured whether models followed the optimal three-step workflow.

I used the following tool usage pattern to differentiate between successful vs unsuccessful reviews:

- **Success:** `create_pending_pull_request_review` → `add_comment_to_pending_review` → `submit_pending_pull_request_review`
- **Failure:** Single-step `create_and_submit_pull_request_review` OR no review tools used.  (Sometimes the model decided just to summarize feedback but didn't leave any comments on the PR.)

You can find raw data and results labeled by date `091525` [here](https://github.com/olaservo/mcp-server-instructions-demo/tree/main/evals/).

For this sample of chat sessions, I got the following results:

| Model | With Instructions | Without Instructions | Improvement |
|-------|------------------|---------------------|-------------|
| **GPT-5-Mini** | 8/10 (80%) | 2/10 (20%) | **+60%** |
| **Claude Sonnet-4** | 9/10 (90%) | 10/10 (100%) | N/A |
| **Overall** | 17/20 (85%) | 12/20 (60%) | **+25%** |

In this example, GPT-5-Mini benefitted most from explicit workflow guidance, since Sonnet almost always followed the inline comment workflow by default.
