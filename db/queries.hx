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
old_blob_sha: String,
new_blob_sha: String,
diff_position: String,
diff_content: String,
commit_message: String, author_name: String, author_email: String) =>
	commit <- AddN<Commit>({
	    parent_commit_id: parent_commit_id,
		commit_id: commit_id,
		commit_message: commit_message,
		author_name: author_name,
		author_email: author_email,
		no_of_files_changed: no_of_files_changed,
		old_blob_sha: old_blob_sha,
		new_blob_sha: new_blob_sha,
		diff_position: diff_position,
		diff_content: diff_content
		})
	RETURN commit

// create edges
QUERY CreateRepositoryToBranch (repo_id: String, branch_id: String) =>
    repo <- N<Repository>({repo_id: repo_id})
    branch <- N<Branch>({branch_id: branch_id})
    hasBranch <- AddE<HasBranch>::From(repo)::To(branch)
    RETURN hasBranch


QUERY CreateBranchToCommit (branch_id: String, commit_id: String) =>
    branch <- N<Branch>({branch_id: branch_id})
    commit <- N<Commit>({commit_id: commit_id})
    hasCommit <- AddE<HasCommit>::From(branch)::To(commit)
    RETURN hasCommit

// create traversals to back to commit node for more info
// create COmmitVector and add edge
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
    commit_vectors <- N<CommitVector>::COUNT
    RETURN commit_vectors
