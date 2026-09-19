use git_indexer::extraction::extract;
use git_indexer::models::{ChangeType, FileChange, GitInfo};
use helix_rs::{HelixDB, HelixDBClient};
use serde_json::json;
use std::path::Path;

/// Helper to query and return None if "No value found" error occurs
async fn query_optional(
    client: &HelixDB,
    query_name: &str,
    params: &serde_json::Value,
) -> Result<Option<serde_json::Value>, Box<dyn std::error::Error>> {
    match client.query::<_, serde_json::Value>(query_name, params).await {
        Ok(result) => {
            if result.is_null() || result == json!([]) {
                Ok(None)
            } else {
                Ok(Some(result))
            }
        }
        Err(e) => {
            let err_str = e.to_string();
            // Treat "No value found" as not existing (return None)
            if err_str.contains("No value found") {
                Ok(None)
            } else {
                Err(e.into())
            }
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize Helix client
    // Adjust endpoint/port as needed, or use env vars
    let client = HelixDB::new(
        Some("http://localhost"),
        Some(7000),
        None, // API key if needed
    );

    // Path to the repository to index
    let repo_path = std::env::args().nth(1).unwrap_or_else(|| ".".to_string());

    println!("Extracting git info from: {}", repo_path);

    // Extract git information
    let git_info = extract(Path::new(&repo_path))?;

    // Generate repo_id from path (you could use a hash or UUID instead)
    let repo_name = Path::new(&repo_path)
        .canonicalize()?
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "unknown".to_string());
    let repo_id = format!("repo-{}", sanitize_id(&repo_name));

    // Ingest everything
    ingest_repository(&client, &git_info, &repo_id, &repo_name).await?;

    println!("\n=== INGESTION COMPLETE ===");
    println!("  Repository: {} ({})", repo_name, repo_id);
    println!("  Branches: {}", git_info.branches.len());
    println!("  Commits: {}", git_info.commits.len());

    let total_file_changes: usize = git_info.commits.iter().map(|c| c.file_changes.len()).sum();
    println!("  File changes: {}", total_file_changes);

    Ok(())
}

async fn ingest_repository(
    client: &HelixDB,
    git_info: &GitInfo,
    repo_id: &str,
    repo_name: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    // 1. Create or Update Repository node
    println!("Processing repository: {}", repo_name);
    let existing_repo = query_optional(client, "GetRepositoryById", &json!({ "repo_id": repo_id })).await?;

    if existing_repo.is_some() {
        println!("  Repository {} already exists, updating...", repo_name);
        let _: serde_json::Value = client
            .query(
                "UpdateRepository",
                &json!({
                    "repo_id": repo_id,
                    "new_name": repo_name,
                    "new_created_at": chrono::Utc::now().to_rfc3339(),
                }),
            )
            .await?;
    } else {
        let _: serde_json::Value = client
            .query(
                "CreateRepository",
                &json!({
                    "repo_id": repo_id,
                    "name": repo_name,
                    "created_at": chrono::Utc::now().to_rfc3339(),
                }),
            )
            .await?;
        println!("  Created repository: {}", repo_name);
    }

    // 2. Create or Update Branch nodes
    println!("\nProcessing {} branches...", git_info.branches.len());
    for branch in &git_info.branches {
        let branch_id = format!("{}:{}", repo_id, sanitize_id(&branch.name));

        let existing_branch = query_optional(client, "GetBranchById", &json!({ "branch_id": branch_id })).await?;

        if existing_branch.is_some() {
            println!("  Updating branch: {}", branch.name);
            let _: serde_json::Value = client
                .query(
                    "UpdateBranch",
                    &json!({
                        "repo_id": repo_id,
                        "branch_id": branch_id,
                        "new_name": branch.name,
                        "new_current_head": branch.is_head,
                        "new_has_remote": branch.is_remote
                    }),
                )
                .await?;
        } else {
            let _: serde_json::Value = client
                .query(
                    "CreateBranch",
                    &json!({
                        "repo_id": repo_id,
                        "branch_id": branch_id,
                        "name": branch.name,
                        "current_head": branch.is_head,
                        "has_remote": branch.is_remote
                    }),
                )
                .await?;

            // Create HasBranch edge (Repository -> Branch)
            let _: serde_json::Value = client
                .query(
                    "CreateRepositoryToBranch",
                    &json!({
                        "repo_id": repo_id,
                        "branch_id": branch_id,
                    }),
                )
                .await?;

            println!("  Created branch: {}", branch.name);
        }
    }

    // 3. Create or Skip Commit nodes (commits are immutable)
    println!("\nProcessing {} commits...", git_info.commits.len());
    for commit in &git_info.commits {
        let existing_commit = query_optional(client, "GetCommitById", &json!({ "commit_id": commit.id })).await?;

        if existing_commit.is_some() {
            // Commits are immutable in git, skip if already exists
            println!("  Commit already exists: {} - {}", &commit.id[..8], commit.message);
            continue;
        }

        // Parse author: "Name <email>" -> (name, email)
        let (author_name, author_email) = parse_author(&commit.author);

        // Get first parent commit ID (empty string for root commits)
        let parent_commit_id = commit.parent_ids.first().cloned().unwrap_or_default();

        // Aggregate diff content from all file changes
        let (diff_position, diff_content) = aggregate_diffs(&commit.file_changes);

        // Create Commit node
        let _: serde_json::Value = client
            .query(
                "CreateCommit",
                &json!({
                    "parent_commit_id": parent_commit_id,
                    "commit_id": commit.id,
                    "commit_message": commit.message,
                    "author_name": author_name,
                    "author_email": author_email,
                    "no_of_files_changed": commit.file_changes.len() as i32,
                    "diff_position": diff_position,
                    "diff_content": diff_content,
                    "timestamp": commit.timestamp,
                }),
            )
            .await?;

        println!("  Created commit: {} - {}", &commit.id[..8], commit.message);

        // 4. Process file changes: Create File nodes and ModifiedFile edges
        for fc in &commit.file_changes {
            let file_id = format!("{}:{}", repo_id, sanitize_id(&fc.path));
            let (filename, extension) = extract_filename_and_extension(&fc.path);

            // Check if File node exists
            let existing_file = query_optional(client, "GetFileById", &json!({ "file_id": file_id })).await?;

            if existing_file.is_none() {
                // Create new File node
                let _: serde_json::Value = client
                    .query(
                        "CreateFile",
                        &json!({
                            "file_id": file_id,
                            "repo_id": repo_id,
                            "file_path": fc.path,
                            "filename": filename,
                            "extension": extension,
                        }),
                    )
                    .await?;
            }

            // Create ModifiedFile edge (Commit -> File)
            let _: serde_json::Value = client
                .query(
                    "CreateModifiedFile",
                    &json!({
                        "commit_id": commit.id,
                        "file_id": file_id,
                        "change_type": change_type_to_string(&fc.change_type),
                        "old_blob_sha": fc.old_blob_sha.clone().unwrap_or_default(),
                        "new_blob_sha": fc.new_blob_sha.clone().unwrap_or_default(),
                    }),
                )
                .await?;

            // Update HasFile edge for each branch that contains this commit
            // For now, we'll handle this in the branch linking step
        }

        // 5. Create CommitVector for semantic search (only for new commits)
        if !diff_content.is_empty() {
            let _: serde_json::Value = client
                .query(
                    "CreateCommitVector",
                    &json!({
                        "commit_id": commit.id,
                        "diff_position": diff_position,
                        "diff_content": diff_content,
                    }),
                )
                .await?;
        }
    }

    // 6. Link branches to their tip commits and update HasFile edges
    println!("\nLinking branches to commits and files...");
    for branch in &git_info.branches {
        let branch_id = format!("{}:{}", repo_id, sanitize_id(&branch.name));

        // Find the tip commit - skip if not in our extracted commits
        let tip_commit = match git_info.commits.iter().find(|c| c.id == branch.commit_id) {
            Some(c) => c,
            None => {
                println!("  Skipping branch {} - commit {} not in extracted commits", 
                    branch.name, &branch.commit_id[..8.min(branch.commit_id.len())]);
                continue;
            }
        };

        // Check if commit exists in database before creating edge
        let existing_commit = query_optional(client, "GetCommitById", &json!({ "commit_id": branch.commit_id })).await?;

        if existing_commit.is_none() {
            println!("  Skipping branch {} - commit {} not in database", 
                branch.name, &branch.commit_id[..8.min(branch.commit_id.len())]);
            continue;
        }

        // Create BranchToCommit edge (only if commit exists)
        let _: serde_json::Value = client
            .query(
                "CreateBranchToCommit",
                &json!({
                    "branch_id": branch_id,
                    "commit_id": branch.commit_id,
                }),
            )
            .await?;

        // Update HasFile edges for files in that commit
        {
            // Get all existing HasFile edges for this branch
            let existing_edges: serde_json::Value = client
                .query(
                    "GetHasFileEdges",
                    &json!({ "branch_id": branch_id }),
                )
                .await?;

            // Build a map of file_id -> edge_id for existing edges
            // The edge response includes the target file info via traversal
            let mut edge_map: std::collections::HashMap<String, String> = std::collections::HashMap::new();
            if let Some(edges) = existing_edges.as_array() {
                for edge in edges {
                    // Extract edge id and target file_id from the edge data
                    if let (Some(edge_id), Some(to_node)) = (
                        edge.get("hasFileEdges").and_then(|e| e.get("id")).and_then(|id| id.as_str()),
                        edge.get("hasFileEdges").and_then(|e| e.get("to")).and_then(|to| to.get("file_id")).and_then(|fid| fid.as_str()),
                    ) {
                        edge_map.insert(to_node.to_string(), edge_id.to_string());
                    }
                }
            }

            for fc in &tip_commit.file_changes {
                let file_id = format!("{}:{}", repo_id, sanitize_id(&fc.path));
                let is_deleted = matches!(fc.change_type, ChangeType::Deleted);
                let current_blob_sha = fc.new_blob_sha.clone().unwrap_or_default();

                // Ensure File node exists before creating/updating HasFile edge
                let existing_file = query_optional(client, "GetFileById", &json!({ "file_id": file_id })).await?;

                if existing_file.is_none() {
                    // File doesn't exist - create it first
                    let (filename, extension) = extract_filename_and_extension(&fc.path);
                    let _: serde_json::Value = client
                        .query(
                            "CreateFile",
                            &json!({
                                "file_id": file_id,
                                "repo_id": repo_id,
                                "file_path": fc.path,
                                "filename": filename,
                                "extension": extension,
                            }),
                        )
                        .await?;
                }

                if let Some(edge_id) = edge_map.get(&file_id) {
                    // Update existing HasFile edge by ID
                    let _: serde_json::Value = client
                        .query(
                            "UpdateHasFileById",
                            &json!({
                                "edge_id": edge_id,
                                "new_blob_sha": current_blob_sha,
                                "new_is_deleted": is_deleted,
                            }),
                        )
                        .await?;
                } else {
                    // Create new HasFile edge
                    let _: serde_json::Value = client
                        .query(
                            "CreateHasFile",
                            &json!({
                                "branch_id": branch_id,
                                "file_id": file_id,
                                "current_blob_sha": current_blob_sha,
                                "is_deleted": is_deleted,
                            }),
                        )
                        .await?;
                }
            }
        }
    }

    Ok(())
}

/// Extract filename and extension from a file path
fn extract_filename_and_extension(path: &str) -> (String, String) {
    let path = Path::new(path);
    let filename = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();
    let extension = path
        .extension()
        .map(|e| e.to_string_lossy().to_string())
        .unwrap_or_default();
    (filename, extension)
}

/// Parse "Name <email>" format into (name, email)
fn parse_author(author: &str) -> (String, String) {
    if let Some(idx) = author.find('<') {
        let name = author[..idx].trim().to_string();
        let email = author[idx + 1..].trim_end_matches('>').to_string();
        (name, email)
    } else {
        (author.to_string(), String::new())
    }
}

/// Aggregate all diff hunks from file changes into single strings
fn aggregate_diffs(file_changes: &[FileChange]) -> (String, String) {
    let mut positions = Vec::new();
    let mut contents = Vec::new();

    for fc in file_changes {
        for hunk in &fc.hunks {
            // Format: "path:old_start-old_lines:new_start-new_lines"
            positions.push(format!(
                "{}:{}-{}:{}-{}",
                fc.path, hunk.old_start, hunk.old_lines, hunk.new_start, hunk.new_lines
            ));
            contents.push(format!("// {}\n{}", fc.path, hunk.content));
        }
    }

    (positions.join(";"), contents.join("\n---\n"))
}

/// Convert ChangeType enum to string
fn change_type_to_string(change_type: &ChangeType) -> String {
    match change_type {
        ChangeType::Added => "Added".to_string(),
        ChangeType::Deleted => "Deleted".to_string(),
        ChangeType::Modified => "Modified".to_string(),
        ChangeType::Renamed { similarity } => format!("Renamed({}%)", similarity),
        ChangeType::Copied { similarity } => format!("Copied({}%)", similarity),
    }
}

/// Sanitize string for use in IDs (remove special chars)
fn sanitize_id(s: &str) -> String {
    s.chars()
        .map(|c| {
            if c.is_alphanumeric() || c == '-' || c == '_' {
                c
            } else {
                '-'
            }
        })
        .collect()
}
