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
    INDEX current_commit_id: String,
    current_head: Boolean,
    has_remote: Boolean
}


// commit
N::Commit{
    INDEX branch_id: String,
    INDEX commit_id: String,
	commit_message: String,
	author_name: String,
	author_email: String,
	timestamp: Date DEFAULT NOW,
	INDEX parent_commit_id: String,
	changed_files_array: String,
}

// file Changes
N::FileChanges{
    INDEX commit_id: String,
    INDEX file_id: String,
    file_name: String,
    file_path: String,
    is_renamed: Boolean,
    old_path: String DEFAULT "",
    change_type: String,
    //timestamp: Date DEFAULT NOW,
    changed_diff_hunks_array: String
}

// diff hunks
N::DiffHunks{
    INDEX file_id: String,
    INDEX diff_hunk_id: String,
    old_start_position: I64,
    old_start_count: I64,
    new_line_position:I64,
    new_line_count:I64,
    diff: String,
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

E::CommitHasDiffHunks{
    From: Commit,
    To: DiffHunks
}

E::HasFileChanges{
    From: Commit,
    To: FileChanges
}


E::HasDiff{
    From: Commit,
    To: DiffHunks,
}

E::FileChangesHasDiffHunks{
    From: FileChanges,
    To: DiffHunks
}

E::DiffHunksToDiffHunksVector{
    From: DiffHunks,
    To: DiffHunksVector
}

// vector
V::DiffHunksVector{
    INDEX diff_hunk_id: String,
    //old_start_position: I64,
    //old_start_count: I64,
    //new_line_position:I64,
    //new_line_count:I64,
    diff: String,
    created_at: Date DEFAULT NOW
}
