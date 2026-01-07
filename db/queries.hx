// we are using gemini if you want to use openai then add OPENAI_API_KEY in .env as mentioned in .env.example
// NOTE: you cannot use one embedding model and then switch, what you start with is what you can ingest, if you want to switch embedding providers the image needs to be rebuilt

// create all nodes
QUERY CreateRepository (repo_id: String, name: String, created_at: Date) =>
    repo <- AddN<Repository>({
        repo_id: repo_id,
        name: name,
        created_at: created_at,
    })
    RETURN repo

// create branch node
QUERY CreateBranch (repo_id: String, branch_id: String, name: String, current_head: Boolean, has_remote: Boolean) =>
	branch <- AddN<Branch>({
	    repo_id: repo_id,
		branch_id: branch_id,
	    name: name,
	    current_head: current_head,
	    has_remote: has_remote
	})
	RETURN branch

// create Commit node
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

// create file node
QUERY CreateFile(file_id: String, repo_id: String, file_path: String, filename: String, extension: String) =>
    file <- AddN<File>({
        file_id: file_id,
        repo_id: repo_id,
        file_path: file_path,
        filename: filename,
        extension: extension
    })
    RETURN file

// create commit to file

QUERY CreateHasFile(branch_id: String, file_id: String, current_blob_sha: String, is_deleted: Boolean) =>
    branch <- N<Branch>({branch_id: branch_id})
    file <- N<File>({file_id: file_id})
    hasFile <- AddE<HasFile>({
        current_blob_sha: current_blob_sha,
        is_deleted: is_deleted
    })::From(branch)::To(file)
    RETURN hasFile


// create modified file
QUERY CreateModifiedFile(commit_id: String, file_id: String, change_type: String, old_blob_sha: String, new_blob_sha: String) =>
    commit <- N<Commit>({commit_id: commit_id})
    file <- N<File>({file_id: file_id})
    modifiedFile <- AddE<ModifiedFile>({
    change_type: change_type,
        old_blob_sha: old_blob_sha,
        new_blob_sha: new_blob_sha
    })::From(commit)::To(file)
    RETURN modifiedFile

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


// create traversals to back to commit node for more info
// create CommitVector and add edge
#[model("gemini:gemini-embedding-001:RETRIEVAL_DOCUMENT")]
QUERY CreateCommitVector( commit_id: String, diff_position: String, diff_content: String) =>
    commit_node <- N<Commit>({commit_id: commit_id})
    // ask xav if we can pass multiple files in `Embed`
    commit_vector_node <- AddV<CommitVector>(Embed(diff_content), {commit_id: commit_id,diff_position: diff_position, diff_content: diff_content})
    edge <- AddE<HasCommitVector>::From(commit_node)::To(commit_vector_node)
    RETURN commit_vector_node


// get repo by id
QUERY GetRepositoryById(repo_id: String)=>
    repo <- N<Repository>({repo_id: repo_id})
    RETURN repo

// get branch by id
QUERY GetBranchById(branch_id: String)=>
    branch <- N<Branch>({branch_id: branch_id})
    RETURN branch

// get file by id
QUERY GetFileById(file_id: String)=>
    file <- N<File>({file_id: file_id})
    RETURN file

QUERY GetCommitById(commit_id: String)=>
    commit <- N<Commit>({commit_id: commit_id})
    RETURN commit

// get hasfile - traverse from branch to get all HasFile edges, 
// then filter in application code by checking if the edge's target file matches
QUERY GetHasFileEdges(branch_id: String) =>
    branch <- N<Branch>({branch_id: branch_id})
    hasFileEdges <- branch::OutE<HasFile>
    RETURN hasFileEdges

// get the file node that a HasFile edge points to
QUERY GetFileFromHasFileEdge(edge_id: ID) =>
    edge <- E<HasFile>(edge_id)
    file <- edge::ToN
    RETURN file

// update repo by repo id
QUERY UpdateRepository(repo_id: String, new_name: String, new_created_at: Date)=>
    updated <- N<Repository>({repo_id: repo_id})::UPDATE({
        name: new_name,
        created_at: new_created_at
    })
    RETURN updated


// update branch by branch id
QUERY UpdateBranch(repo_id: String, branch_id: String, new_name: String, new_current_head: Boolean, new_has_remote: Boolean)=>
    updated <- N<Branch>({branch_id: branch_id})::UPDATE({
        name: new_name,
        current_head: new_current_head,
        has_remote: new_has_remote
    })
    RETURN updated

// update commit by id
QUERY UpdateCommit(new_parent_commit_id: String, commit_id:String, new_commit_message:String, new_author_name: String, new_author_email:String, new_no_of_files_changed: I32, new_diff_position:String, new_diff_content:String, new_timestamp: I64)=>
    updated <- N<Commit>({commit_id: commit_id})::UPDATE({
        parent_commit_id: new_parent_commit_id,
        commit_message: new_commit_message,
        author_name: new_author_name,
        author_email: new_author_email,
        no_of_files_changed: new_no_of_files_changed,
        diff_position: new_diff_position,
        diff_content: new_diff_content,
        timestamp:new_timestamp
        })
    RETURN updated

// update file
QUERY UpdateFile(file_id: String, new_filename: String, new_extension: String) =>
    updated <- N<File>({file_id: file_id})::UPDATE({
        filename: new_filename,
        extension: new_extension
    })
    RETURN updated

// update hasfile edge by edge_id (get edge_id from GetHasFileEdges first)
QUERY UpdateHasFileById(edge_id: ID, new_blob_sha: String, new_is_deleted: Boolean) =>
    hasFile <- E<HasFile>(edge_id)
    updated <- hasFile::UPDATE({
        current_blob_sha: new_blob_sha,
        is_deleted: new_is_deleted
    })
    RETURN updated

// we get count for total number of items in that node so we can equally split them to spawn threads + parallelize
// double regex hits like zed search(https://zed.dev/blog/nerd-sniped-project-search)

// get all repos
QUERY GetAllRepos () =>
    repos <- N<Repository>
    RETURN repos
// get all commits
QUERY GetAllCommits () =>
    commits <- N<Commit>
    RETURN commits
// get all commit vector
QUERY GetAllCommitVectors () =>
    commit_vectors <- V<CommitVector>
    RETURN commit_vectors

// we get count because we want to parallelize
// get all branches count
QUERY GetAllBranchesCount () =>
    branches <- N<Branch>::COUNT
    RETURN branches
// get all repos count
QUERY GetAllReposCount () =>
    repos <- N<Repository>::COUNT
    RETURN repos
// get all commits count
QUERY GetAllCommitsCount () =>
    commits <- N<Commit>::COUNT
    RETURN commits
// get all commit vector count
QUERY GetAllCommitVectorsCount () =>
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
// delete all commits vectors
QUERY DeleteAllVectorCommits()=>
    DROP V<CommitVector>
    RETURN "Deleted all vector commits"
