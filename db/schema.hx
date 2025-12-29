// repository
N::Repository{
    INDEX repo_id: String,
    INDEX name: String,
    created_at: Date DEFAULT NOW
}

// branch (group of commits)
N::Branch{
    INDEX repo_id: String,
	INDEX branch_id: String,
    name: String,
    //INDEX current_commit_id: String,
    current_head: Boolean,
    has_remote: Boolean
}

// commit
N::Commit{
    INDEX parent_commit_id: String,
    //INDEX branch_id: String,
    INDEX commit_id: String, // needs to be sha
	commit_message: String,
	author_name: String,
	author_email: String,
	no_of_files_changed: I32,
	old_blob_sha: String,
	new_blob_sha: String,
	//timestamp: Date DEFAULT NOW,
	diff_position: String,
	diff_content:String,
	//changed_files_array: String,
}

// edges
E::HasBranch{
    From: Repository,
    To: Branch
}

E::HasCommit{
    From: Branch,
    To: Commit
}
// commit to commit_vector
E::HasCommitVector{
    From: Commit,
    To: CommitVector,
}

V::CommitVector{
    INDEX commit_id: String,
	diff_position: String,
	diff_content:String,
}
