// create all nodes
QUERY CreateRepository (repo_id: String, name: String, created_at: Date) =>
    repo <- AddN<Repository>({
        repo_id: repo_id,
        name: name,
        created_at: created_at,
    })
    RETURN repo

// Branch
QUERY CreateBranch (repo_id: String, branch_id: String, name: String, current_commit_id: String, current_head: Boolean, has_remote: Boolean) =>
	branch <- AddN<Branch>({
	    repo_id: repo_id,
		branch_id: branch_id,
	    name: name,
	    current_commit_id: current_commit_id,
	    current_head: current_head,
	    has_remote: has_remote
	})
	RETURN branch

// Commit
QUERY CreateCommit (branch_id:String,commit_id: String, commit_message: String, author_name: String, author_email: String, timestamp: Date, parent_commit_id: String, changed_files_array: String ) =>
	commit <- AddN<Commit>({
	    branch_id: branch_id,
		commit_id: commit_id,
		commit_message: commit_message,
		author_name: author_name,
		author_email: author_email,
		timestamp: timestamp,
		parent_commit_id: parent_commit_id,
		changed_files_array: changed_files_array,
	})
	RETURN commit


QUERY CreateFileChanges (commit_id: String, file_id: String, file_name: String, file_path: String, is_renamed: Boolean, old_path: String, change_type: String, changed_diff_hunks_array: String) =>
    file_changes <- AddN<FileChanges>({
    commit_id: commit_id,
    file_id: file_id,
    file_name: file_name,
    file_path: file_path,
    is_renamed: is_renamed,
    old_path: old_path,
    change_type: change_type,
    changed_diff_hunks_array: changed_diff_hunks_array,
    })
    RETURN file_changes


QUERY CreateDiffHunk(file_id:String, diff_hunk_id: String, old_start_position: I64, old_start_count: I64, new_line_position:I64, new_line_count:I64, diff: String) =>
    diff_hunks <- AddN<DiffHunks>({
    file_id: file_id,
    diff_hunk_id: diff_hunk_id,
    old_start_position: old_start_position,
    old_start_count: old_start_count,
    new_line_position: new_line_position,
    new_line_count: new_line_count,
    diff: diff,
    })
    RETURN diff_hunks


// create edges
QUERY CreateRepositoryToBranch (repo_id: String, branch_id: String) =>
    repo <- N<Repository>({repo_id: repo_id})
    branch <- N<Branch>({branch_id: branch_id})
    hasBranch <- AddE<HasBranch>::From(repo)::To(branch)
    RETURN hasBranch

QUERY CreateCommitToDiffHunks (commit_id: String, diff_hunk_id: String) =>
    commit <- N<Commit>({commit_id: commit_id})
    diff_hunk <- N<DiffHunks>({diff_hunk_id: diff_hunk_id})
    hasDiffHunks <- AddE<CommitHasDiffHunks>::From(commit)::To(diff_hunk)
    RETURN hasDiffHunks

QUERY CreateBranchToCommit (branch_id: String, commit_id: String) =>
    branch <- N<Branch>({branch_id: branch_id})
    commit <- N<Commit>({commit_id: commit_id})
    hasCommit <- AddE<HasCommit>::From(branch)::To(commit)
    RETURN hasCommit


QUERY CreateCommitToFileChanges(commit_id: String, file_id: String)=>
    commit <- N<Commit>({commit_id: commit_id})
    file_changes <- N<FileChanges>({file_id: file_id})
    hasfileChanges <- AddE<HasFileChanges>::From(commit)::To(file_changes)
    RETURN hasfileChanges


QUERY CreateCommitsToDiffHunks(commit_id: String, diff_hunk_id: String)=>
    commit <- N<Commit>({commit_id: commit_id})
    diff_hunks <- N<DiffHunks>({diff_hunk_id: diff_hunk_id})
    hasDiff <- AddE<HasDiff>::From(commit)::To(diff_hunks)
    RETURN hasDiff

QUERY CreateFileChangesToDiffHunks(file_id: String,
    diff_hunk_id: String)=>
    file_changes <- N<FileChanges>({file_id: file_id})
    diff_hunks <- N<DiffHunks>({diff_hunk_id: diff_hunk_id})
    hasDiff <- AddE<FileChangesHasDiffHunks>::From(file_changes)::To(diff_hunks)
    RETURN hasDiff


// remember to add OPENAI API KEY in .env for `Embed` to work
QUERY CreateDiffHunksVector(diff_hunk_id: String, diff_content: String, created_at: Date) =>
    diff_hunk_node <- N<DiffHunks>({diff_hunk_id: diff_hunk_id})
    diff_hunks_vector <- AddV<DiffHunksVector>(Embed(diff_content), {diff_hunk_id: diff_hunk_id, diff_content: diff_content, created_at: created_at})
    edge <- AddE<DiffHunksToDiffHunksVector>::From(diff_hunk_node)::To(diff_hunks_vector)
    RETURN diff_hunks_vector


// commit keyword search
QUERY SearchKeywordCommit(keywords: String, limit:I64)=>
    results <- SearchBM25<Commit>(keywords, limit)
    RETURN results

// will need more keyword searches

// semantic search search diff hunks
QUERY SearchDiffHunksVector (query: String, limit: I64) =>
    results <- SearchV<DiffHunksVector>(Embed(query), limit)
    RETURN results


// get all -> for total amount of everything
// get all branches
QUERY GetAllBranches () =>
    branches <- N<Branch>
    RETURN branches
// get all repos
QUERY GetAllRepos () =>
    repos <- N<Repository>
    RETURN repos
// get all commits
QUERY GetAllCommits () =>
    commits <- N<Commit>
    RETURN commits
// get all filechanges?
QUERY GetAllFileChanges()=>
    file_changes <- N<FileChanges>
    RETURN file_changes
// get all diff hunks
QUERY GetAllDiffHunks()=>
    diff_hunks <- N<DiffHunks>
    RETURN diff_hunks
// get all diff hunks vector
QUERY GetAllDiffHunkVectors()=>
    diff_hunk_vectors <- N<DiffHunksVector>
    RETURN diff_hunk_vectors



// split up total spawn threads -> parallelize
