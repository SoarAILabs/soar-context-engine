use git_indexer::extraction::extract;
use git_indexer::models::{ChangeType, FileChange, GitInfo};
use helix_rs::{HelixDB, HelixDBClient};
use serde_json::json;
use std::path::Path;

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
    // 1. Create Repository node
    println!("Creating repository: {}", repo_name);
    // check if repo exists
    // let existing: serde_json::Value = client
    //     .query(
    //         "GetRepositoryById",
    //         &json!({
    //             "repo_id": repo_id
    //         }),
    //     )
    //     .await?;
    // if !existing.is_null() && existing != json!([]) {
    //     println!("Repository {} already exists, updating instead", repo_name)
    //     // update logic here
    //     // let update: serde_json::Value = client.query(
    //     //     "Update"
    //     // )
    // }
    let result: serde_json::Value = client
        .query(
            "CreateRepository",
            &json!({
                "repo_id": repo_id,
                "name": repo_name,
                "created_at": chrono::Utc::now().to_rfc3339(),
            }),
        )
        .await?;
    println!("  Created repository: {:?}", result);

    // 2. Create Branch nodes and Repository->Branch edges
    println!("\nCreating {} branches...", git_info.branches.len());
    for branch in &git_info.branches {
        let branch_id = format!("{}:{}", repo_id, sanitize_id(&branch.name));

        let _: serde_json::Value = client
            .query(
                "CreateBranch",
                &json!({
                    "repo_id": repo_id,
                    "branch_id": branch_id,
                    "name": branch.name,
                    "current_head": branch.is_head,
                    "has_remote": branch.is_remote,
                }),
            )
            .await?;

        // Create edge: Repository -> Branch
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

    // 3. Create Commit nodes, FileChange nodes, and edges
    println!("\nCreating {} commits...", git_info.commits.len());
    for commit in &git_info.commits {
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

        // 4. Create FileChange nodes for each file in this commit
        for (idx, fc) in commit.file_changes.iter().enumerate() {
            let file_change_id = format!("{}:fc:{}", commit.id, idx);

            let _: serde_json::Value = client
                .query(
                    "CreateFileChange",
                    &json!({
                        "commit_id": commit.id,
                        "file_change_id": file_change_id,
                        "path": fc.path,
                        "change_type": change_type_to_string(&fc.change_type),
                        "old_blob_sha": fc.old_blob_sha.clone().unwrap_or_default(),
                        "new_blob_sha": fc.new_blob_sha.clone().unwrap_or_default(),
                    }),
                )
                .await?;

            // Create edge: Commit -> FileChange
            let _: serde_json::Value = client
                .query(
                    "CreateCommitToFileChange",
                    &json!({
                        "commit_id": commit.id,
                        "file_change_id": file_change_id,
                    }),
                )
                .await?;
        }

        // 5. Create CommitVector for semantic search
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

    // 6. Link branches to their tip commits
    println!("\nLinking branches to commits...");
    for branch in &git_info.branches {
        let branch_id = format!("{}:{}", repo_id, sanitize_id(&branch.name));

        let _: serde_json::Value = client
            .query(
                "CreateBranchToCommit",
                &json!({
                    "branch_id": branch_id,
                    "commit_id": branch.commit_id,
                }),
            )
            .await?;
    }

    Ok(())
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
