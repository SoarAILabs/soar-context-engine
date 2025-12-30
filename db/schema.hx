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
    current_head: Boolean,
    has_remote: Boolean
}

// commit
N::Commit{
    INDEX parent_commit_id: String,
    INDEX commit_id: String,
	commit_message: String,
	author_name: String,
	author_email: String,
	no_of_files_changed: I32,
	diff_position: String,
	diff_content:String,
	timestamp: I64
}

// file changes
N::FileChange{
    INDEX file_change_id: String,
    INDEX commit_id: String,
    path: String,
    change_type: String,
    old_blob_sha: String,
    new_blob_sha: String,
}


// vectors
V::CommitVector{
    INDEX commit_id: String,
	diff_position: String,
	diff_content:String,
}

// edges
E::HasFileChange{
    From:Commit,
    To: FileChange
}
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
