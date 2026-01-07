// create all nodes
QUERY CreateRepository (repo_id: String, name: String, created_at: Date) =>
    repo <- AddN<Repository>({
        repo_id: repo_id,
        name: name,
        created_at: created_at,
    })
    RETURN repo

// Branch
QUERY CreateBranch (repo_id: String, branch_id: String, name: String, current_head: Boolean, has_remote: Boolean) =>
	branch <- AddN<Branch>({
	    repo_id: repo_id,
		branch_id: branch_id,
	    name: name,
	    current_head: current_head,
	    has_remote: has_remote
	})
	RETURN branch

// Commit
QUERY CreateCommit (parent_commit_id: String,commit_id: String,
no_of_files_changed: I32,
diff_position: String,
diff_content: String,
commit_message: String, author_name: String, author_email: String, timestamp: I64) =>
	commit <- AddN<Commit>({
	    parent_commit_id: parent_commit_id,
		commit_id: commit_id,
		commit_message: commit_message,
		author_name: author_name,
		author_email: author_email,
		no_of_files_changed: no_of_files_changed,
		diff_position: diff_position,
		diff_content: diff_content
		,timestamp: timestamp})
	RETURN commit

QUERY CreateFileChange(commit_id: String, file_change_id: String, path: String, change_type: String, old_blob_sha: String, new_blob_sha: String) =>
    file_change <- AddN<FileChange>({
    commit_id: commit_id,
    file_change_id: file_change_id,
    path: path,
    change_type: change_type,
    old_blob_sha: old_blob_sha,
    new_blob_sha: new_blob_sha
})
    RETURN file_change

// edge from repo to branch
QUERY CreateRepositoryToBranch (repo_id: String, branch_id: String) =>
    repo <- N<Repository>({repo_id: repo_id})
    branch <- N<Branch>({branch_id: branch_id})
    hasBranch <- AddE<HasBranch>::From(repo)::To(branch)
    RETURN hasBranch

// edge from branch to commit
QUERY CreateBranchToCommit (branch_id: String, commit_id: String) =>
    branch <- N<Branch>({branch_id: branch_id})
    commit <- N<Commit>({commit_id: commit_id})
    hasCommit <- AddE<HasCommit>::From(branch)::To(commit)
    RETURN hasCommit


    //  edge from Commit to FileChange
QUERY CreateCommitToFileChange (commit_id: String, file_change_id: String) =>
    commit <- N<Commit>({commit_id: commit_id})
    file_change <- N<FileChange>({file_change_id: file_change_id})
    edge <- AddE<HasFileChange>::From(commit)::To(file_change)
    RETURN edge


// create traversals to back to commit node for more info
// create CommitVector and add edge
// uncomment if want to use gemini
//#[model("gemini:gemini-embedding-001:RETRIEVAL_DOCUMENT")]
QUERY CreateCommitVector( commit_id: String, diff_position: String, diff_content: String) =>
    commit_node <- N<Commit>({commit_id: commit_id})
    // ask xav if we can pass multiple files in `Embed`
    commit_vector_node <- AddV<CommitVector>(Embed(diff_content), {commit_id: commit_id,diff_position: diff_position, diff_content: diff_content})
    edge <- AddE<HasCommitVector>::From(commit_node)::To(commit_vector_node)
    RETURN commit_vector_node


// we get count for total number of items in that node.
// now we can equally split them to spawn threads + parallelize
// double regex hits like zed search(https://zed.dev/blog/nerd-sniped-project-search)


// we get count because we want to parallelize
// get all branches
QUERY GetAllBranches () =>
    branches <- N<Branch>::COUNT
    RETURN branches
// get all repos
QUERY GetAllRepos () =>
    repos <- N<Repository>::COUNT
    RETURN repos
// get all commits
QUERY GetAllCommits () =>
    commits <- N<Commit>::COUNT
    RETURN commits
// get all commit vector
QUERY GetAllCommitVectors () =>
    commit_vectors <- V<CommitVector>::COUNT
    RETURN commit_vectors

// delete all branches
QUERY DeleteAllBranches()=>
    DROP N<Branch>
    RETURN "Deleted all branches"
// delete all repos
QUERY DeleteAllRepos()=>
    DROP N<Repository>
    RETURN "Deleted all repos"
// delete all commits
QUERY DeleteAllCommits()=>
    DROP N<Commit>
    RETURN "Deleted all commits"
// delete all commits
QUERY DeleteAllVectorCommits()=>
    DROP N<CommitVector>
    RETURN "Deleted all vector commits"
// delete all file changes
QUERY DeleteAllVectorCommits()=>
    DROP N<FileChange>
    RETURN "Deleted all file changes"
