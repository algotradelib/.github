# algotradelib/.github

The organization's profile (`profile/README.md`) and the CI steps its repositories share.

## Actions

Use them as `algotradelib/.github/actions/<name>@main`; a change here changes every repository's CI at once.

| Action | What it does |
| --- | --- |
| `setup-atl` | Downloads the installed algotradelib (with Boost and Eigen) for the runner and adds it to `CMAKE_PREFIX_PATH`; output `path`. |
| `setup-atlc` | Downloads atlc for the runner and puts it on `PATH`; outputs `path` and `atlc`. |
| `format-check` | Checks C++ files against the repository's `.clang-format`, with no visual alignment and no padded comments; inputs `files`, `exclude`, `markdown`, `tabs`. |
| `update-tap` | Points the repository's formula in `algotradelib/homebrew-atls` at the commit just pushed to `main` (its `revision:` and a higher `version`), and pushes the tap; inputs `formula`, `token` (one that can push to the tap), `commit` and `committed-at` (the pushed head commit by default; from a `workflow_run` after CI, the tested one). |

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: algotradelib/.github/actions/setup-atl@main
  - id: atlc
    uses: algotradelib/.github/actions/setup-atlc@main
  - run: cmake -S . -B build && cmake --build build
```

```yaml
- uses: algotradelib/.github/actions/format-check@main
  with:
    files: "*.hpp *.cpp :(glob)include/mylib/*"
    markdown: "README*.md docs/*.md"
```

`actions/format-check/check-format.sh` runs the same check locally, from a repository's root, with that repository's lists:
`FORMAT_FILES='*.hpp *.cpp' FORMAT_MARKDOWN='README*.md' path/to/.github/actions/format-check/check-format.sh`.
