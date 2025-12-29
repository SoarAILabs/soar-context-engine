=== BRANCHES (3) ===
  context-engine-new-db -> dc4f6c5c (HEAD)
  main -> dc4f6c5c
  origin/main -> dc4f6c5c [remote]

=== TAGS (0) ===

=== COMMITS (showing first 10 of 14) ===

Commit: dc4f6c5c
  Tree:    7a9fe38c // git ls-tree 7a9fe38c
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: add search diff hunks vector with reranker rrf query with range 0-10 +
parameters for tuning

  Parents: ["15864e90"]
  Files changed: 1
    Modified db/queries.hx (blob: a2d3ab35 -> dff032e4)
        @@ -130,6 +130,18 @@
             results <- SearchV<DiffHunksVector>(Embed(query), limit)
             RETURN results


Commit: 15864e90
  Tree:    79eb0e67
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: add keyword search query for filechanges + diffhunks

  Parents: ["919ebcfc"]
  Files changed: 1
    Modified db/queries.hx (blob: 2bf72cb6 -> a2d3ab35)
        @@ -115,7 +115,15 @@
             results <- SearchBM25<Commit>(keywords, limit)
             RETURN results


Commit: 919ebcfc
  Tree:    2ec3495b
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: env example + query comments for search

  Parents: ["060e5cb2"]
  Files changed: 2
    Modified db/queries.hx (blob: 50c1c358 -> 2bf72cb6)
        @@ -122,12 +122,9 @@
             results <- SearchV<DiffHunksVector>(Embed(query), limit)
             RETURN results

    Added .env.example (blob: none -> 43da640d)
        @@ -1,0 +1,2 @@
        +HELIX_ENDPOINT=
        +HELIX_API_KEY=

Commit: 060e5cb2
  Tree:    8678c23c
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: add get all node count queries

  Parents: ["24d90b89"]
  Files changed: 1
    Modified db/queries.hx (blob: aa72d863 -> 50c1c358)
        @@ -123,32 +123,33 @@
             RETURN results



Commit: 24d90b89
  Tree:    f0623e12
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: get all queries for branhces, commits, repos, file cahnges, diff hunks &
diff hunk vectors

  Parents: ["12fb5ca7"]
  Files changed: 1
    Modified db/queries.hx (blob: 31ee6645 -> aa72d863)
        @@ -124,11 +124,31 @@


         // get all -> for total amount of everything

Commit: 12fb5ca7
  Tree:    61f13f0b
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: add search commits by keyword + change port to 7000

  Parents: ["e2f8b778"]
  Files changed: 2
    Modified db/queries.hx (blob: b6dc5d4e -> 31ee6645)
        @@ -110,7 +110,25 @@
             RETURN diff_hunks_vector


    Modified helix.toml (blob: 218eb1b1 -> 414e1f6b)
        @@ -1,10 +1,10 @@
         [project]
         name = "context-engine"
         queries = "./db/"

Commit: e2f8b778
  Tree:    5e3b9a02
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: dev -> context engine + debug mode;

  Parents: ["f72c00c8"]
  Files changed: 1
    Modified helix.toml (blob: a69e4ddb -> 218eb1b1)
        @@ -1,10 +1,10 @@
         [project]
         name = "context-engine"
         queries = "./db/"

Commit: f72c00c8
  Tree:    b2663bae
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: rename diff to diff_content to avoid type error(diff -> diff_hunk_node)
+ rename diff -> diff_content in diff hunksVector to avoid name
conflcits

  Parents: ["8ad6d455"]
  Files changed: 2
    Modified db/queries.hx (blob: a5c8388e -> b6dc5d4e)
        @@ -103,10 +103,10 @@


         // remember to add OPENAI API KEY in .env for `Embed` to work
    Modified db/schema.hx (blob: aa021fb9 -> c5d20ce0)
        @@ -92,10 +92,6 @@
         // vector
         V::DiffHunksVector{
             INDEX diff_hunk_id: String,

Commit: 8ad6d455
  Tree:    3e5237f1
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: add indexed ids to create queries for related nodes

  Parents: ["00739228"]
  Files changed: 1
    Modified db/queries.hx (blob: 29244edd -> a5c8388e)
        @@ -1,4 +1,3 @@
        -// every node -> needs to be created
         // create all nodes
         QUERY CreateRepository (repo_id: String, name: String, created_at: Date) =>

Commit: 00739228
  Tree:    0ba6bc9c
  Author:  Amaan Bilwar <bilwarad@mail.uc.edu>
  Message: add .env and helix dir to gitignore

  Parents: ["1934f973"]
  Files changed: 1
    Modified .gitignore (blob: c454da54 -> 3e3d131b)
        @@ -1,2 +1,3 @@
        +.helix/
         target/
         *.env

=== SUMMARY ===
  Total branches: 3
  Total tags: 0
  Total commits: 14
  Total file changes: 22
  Total diff hunks: 25
  Unique blob SHAs: 22
