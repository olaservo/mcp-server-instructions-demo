#!/bin/bash

# MCP GitHub Server Instructions Evaluation Script
# Usage: ./evaluate_instructions.sh <transcript_dir> <output_file>

set -e

TRANSCRIPT_DIR="${1:-.}"
OUTPUT_FILE="${2:-evaluation_results.csv}"

# Initialize CSV with headers
echo "model,instructions_variant,task,success,tool_sequence,error_type,notes,create_pending_count,add_comment_count,submit_pending_count,create_and_submit_count" > "$OUTPUT_FILE"

# Define expected tool sequences for different workflows
declare -A EXPECTED_SEQUENCES=(
    ["pr_review"]="create_pending_pull_request_review,add_comment_to_pending_review,submit_pending_pull_request_review"
    ["simple_pr_comment"]="create_and_submit_pull_request_review"
    ["issue_linking"]="create_issue,create_pull_request"
)

# Function to extract tool calls from JSON transcript
extract_tool_sequence() {
    local transcript_file="$1"
    
    # Extract tool names from toolCallRounds nested in result metadata, removing prefixes to get just the tool name
    jq -r '.requests[].result.metadata.toolCallRounds[].toolCalls[].name' "$transcript_file" 2>/dev/null | 
        sed 's/^mcp_[^_]*_//' | 
        tr '\n' ',' | 
        sed 's/,$//'
}

# Function to check if expected tools are present - checking for complete workflow
check_tools_present() {
    local actual="$1"
    local task="$2"
    local instructions_variant="$3"
    
    # Convert comma-separated list to array for easier checking
    IFS=',' read -ra tools <<< "$actual"
    
    case "$task" in
        "pr_review")
            # For models with instructions, require the full three-step workflow
            if [[ "$instructions_variant" == "with_instructions" ]]; then
                local has_create_pending=false
                local has_add_comment=false
                local has_submit_pending=false
                
                for tool in "${tools[@]}"; do
                    if [[ "$tool" == "create_pending_pull_request_review" ]]; then
                        has_create_pending=true
                    elif [[ "$tool" == "add_comment_to_pending_review" ]]; then
                        has_add_comment=true
                    elif [[ "$tool" == "submit_pending_pull_request_review" ]]; then
                        has_submit_pending=true
                    fi
                done
                
                if [[ "$has_create_pending" == true ]] && [[ "$has_add_comment" == true ]] && [[ "$has_submit_pending" == true ]]; then
                    echo "true"
                else
                    echo "false"
                fi
            else
                # For models without instructions, accept any PR review approach
                for tool in "${tools[@]}"; do
                    if [[ "$tool" == "create_pending_pull_request_review" ]] || 
                       [[ "$tool" == "add_comment_to_pending_review" ]] || 
                       [[ "$tool" == "submit_pending_pull_request_review" ]] || 
                       [[ "$tool" == "create_and_submit_pull_request_review" ]]; then
                        echo "true"
                        return
                    fi
                done
                echo "false"
            fi
            ;;
        "simple_pr_comment")
            # Look for simple PR comment tools
            for tool in "${tools[@]}"; do
                if [[ "$tool" == "create_and_submit_pull_request_review" ]]; then
                    echo "true"
                    return
                fi
            done
            echo "false"
            ;;
        "issue_linking")
            # Look for issue and PR creation tools
            local has_create_issue=false
            local has_create_pr=false
            for tool in "${tools[@]}"; do
                if [[ "$tool" == "create_issue" ]]; then
                    has_create_issue=true
                elif [[ "$tool" == "create_pull_request" ]]; then
                    has_create_pr=true
                fi
            done
            if [[ "$has_create_issue" == true ]] && [[ "$has_create_pr" == true ]]; then
                echo "true"
            else
                echo "false"
            fi
            ;;
        *)
            # Default: same logic as pr_review
            if [[ "$instructions_variant" == "with_instructions" ]]; then
                local has_create_pending=false
                local has_add_comment=false
                local has_submit_pending=false
                
                for tool in "${tools[@]}"; do
                    if [[ "$tool" == "create_pending_pull_request_review" ]]; then
                        has_create_pending=true
                    elif [[ "$tool" == "add_comment_to_pending_review" ]]; then
                        has_add_comment=true
                    elif [[ "$tool" == "submit_pending_pull_request_review" ]]; then
                        has_submit_pending=true
                    fi
                done
                
                if [[ "$has_create_pending" == true ]] && [[ "$has_add_comment" == true ]] && [[ "$has_submit_pending" == true ]]; then
                    echo "true"
                else
                    echo "false"
                fi
            else
                for tool in "${tools[@]}"; do
                    if [[ "$tool" == "create_pending_pull_request_review" ]] || 
                       [[ "$tool" == "add_comment_to_pending_review" ]] || 
                       [[ "$tool" == "submit_pending_pull_request_review" ]] || 
                       [[ "$tool" == "create_and_submit_pull_request_review" ]]; then
                        echo "true"
                        return
                    fi
                done
                echo "false"
            fi
            ;;
    esac
}

# Function to count tool occurrences
count_tool_occurrences() {
    local sequence="$1"
    local tool_name="$2"
    
    # Convert comma-separated list to array and count occurrences
    IFS=',' read -ra tools <<< "$sequence"
    local count=0
    for tool in "${tools[@]}"; do
        if [[ "$tool" == "$tool_name" ]]; then
            ((count++))
        fi
    done
    echo "$count"
}

# Function to detect common error patterns
detect_error_pattern() {
    local transcript_file="$1"
    local sequence="$2"
    
    # Check for immediate submit without pending review
    if [[ "$sequence" == *"create_and_submit_pull_request_review"* ]] && \
       [[ "$sequence" != *"create_pending_pull_request_review"* ]]; then
        echo "immediate_submit"
        return
    fi
    
    # Check for missing line comments
    if [[ "$sequence" == *"create_pending_pull_request_review"* ]] && \
       [[ "$sequence" != *"add_comment_to_pending_review"* ]]; then
        echo "missing_line_comments"
        return
    fi
    
    # Check for wrong order
    if [[ "$sequence" == *"submit_pending_pull_request_review"* ]] && \
       [[ "$sequence" == *"create_pending_pull_request_review"* ]]; then
        local submit_pos=$(echo "$sequence" | grep -b -o "submit_pending_pull_request_review" | cut -d: -f1)
        local create_pos=$(echo "$sequence" | grep -b -o "create_pending_pull_request_review" | cut -d: -f1)
        if [[ $submit_pos -lt $create_pos ]]; then
            echo "wrong_order"
            return
        fi
    fi
    
    echo "none"
}

# Function to parse metadata from filename or content
parse_metadata() {
    local file="$1"
    local basename=$(basename "$file" .json)
    
    # Expected format: model_instructions_task.json
    # e.g., gpt5mini_pr_with_instructions_v1.json
    
    local model=$(echo "$basename" | cut -d'_' -f1)
    local instructions_variant=$(echo "$basename" | grep -o "with_instructions\|NO_instructions" || echo "unknown")
    local task=$(echo "$basename" | grep -o "pr_review\|simple_comment\|issue_link" || echo "pr_review")
    
    echo "$model,$instructions_variant,$task"
}

# Main evaluation loop
echo "Starting evaluation of transcripts in: $TRANSCRIPT_DIR"
echo "Output will be saved to: $OUTPUT_FILE"
echo ""

for transcript in "$TRANSCRIPT_DIR"/*.json; do
    if [[ ! -f "$transcript" ]]; then
        continue
    fi
    
    echo "Processing: $(basename "$transcript")"
    
    # Parse metadata
    metadata=$(parse_metadata "$transcript")
    model=$(echo "$metadata" | cut -d',' -f1)
    instructions=$(echo "$metadata" | cut -d',' -f2)
    task=$(echo "$metadata" | cut -d',' -f3)
    
    # Extract tool sequence
    sequence=$(extract_tool_sequence "$transcript")
    
    # Check if expected tools are present
    success=$(check_tools_present "$sequence" "$task" "$instructions")
    
    # Count tool occurrences
    create_pending_count=$(count_tool_occurrences "$sequence" "create_pending_pull_request_review")
    add_comment_count=$(count_tool_occurrences "$sequence" "add_comment_to_pending_review")
    submit_pending_count=$(count_tool_occurrences "$sequence" "submit_pending_pull_request_review")
    create_and_submit_count=$(count_tool_occurrences "$sequence" "create_and_submit_pull_request_review")
    
    # Detect error patterns
    error_type=$(detect_error_pattern "$transcript" "$sequence")
    
    # Extract any error messages or notes
    notes=$(jq -r '.requests[0].response[] | 
        select(.value != null) | 
        .value | 
        select(. | test("error|failed|issue"; "i")) | 
        . | @base64' "$transcript" 2>/dev/null | 
        head -1 | 
        base64 -d 2>/dev/null | 
        tr '\n' ' ' | 
        cut -c1-100 || echo "")
    
    # Write to CSV
    echo "$model,$instructions,$task,$success,\"$sequence\",$error_type,\"$notes\",$create_pending_count,$add_comment_count,$submit_pending_count,$create_and_submit_count" >> "$OUTPUT_FILE"
done

echo ""
echo "Evaluation complete! Results saved to: $OUTPUT_FILE"
echo ""
echo "Summary:"
echo "--------"
total=$(tail -n +2 "$OUTPUT_FILE" | wc -l)
success=$(grep ",true," "$OUTPUT_FILE" | wc -l)
echo "Total evaluations: $total"
echo "Successful: $success"
echo "Success rate: $(( success * 100 / total ))%"
echo ""
echo "By instruction variant:"
for variant in "with_instructions" "NO_instructions"; do
    variant_total=$(grep ",$variant," "$OUTPUT_FILE" | wc -l)
    variant_success=$(grep ",$variant,.*,true," "$OUTPUT_FILE" | wc -l)
    if [[ $variant_total -gt 0 ]]; then
        echo "  $variant: $variant_success/$variant_total ($(( variant_success * 100 / variant_total ))%)"
    fi
done
