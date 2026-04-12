# RFC-003: Official problem.toml Schema and Migration Checklist

- Status: Draft
- Date: 2026-04-13
- Depends on:
  - RFC-001 (Configuration-Driven Judge Pipeline)
  - RFC-002 (Interactive Runner)
- Scope:
  - Official schema for problem.toml
  - Validation rules
  - Complete examples for each problem type
  - Sprint-based migration checklist from current codebase

## 1. Summary

This RFC defines the official schema v1 for problem.toml and a practical migration plan from the current script-first implementation to the new engine architecture.

Core objectives:

1. Freeze one stable contract for configuration-driven pipelines.
2. Eliminate hardcoded behavior switches by file-name heuristics.
3. Provide a realistic sprint plan with acceptance criteria and rollback gates.

## 2. Design Principles

1. Explicit over implicit:
- No auto-detect by scanning chk.cpp or int.cpp.
- Every behavior must be declared in problem.toml.

2. Strict validation:
- Unknown keys should fail validation.
- Missing required fields should fail early.

3. Backward-compatible rollout:
- Keep existing scripts as wrappers during migration.

4. Deterministic defaults:
- Comparator, limits, and cache policies must have explicit defaults.

## 3. Official Schema v1

## 3.1 Top-level

Required top-level tables:

1. problem
2. build
3. run
4. evaluation

Optional top-level tables:

1. generation
2. scoring
3. cache
4. artifacts
5. extensions

## 3.2 Schema Definition

```toml
schema_version = 1

[problem]
code = "a_plus_b"
name = "A + B"
type = "traditional" # traditional | custom_checker | interactive | grader
tags = ["math", "implementation"]

[build]
language = "cpp17"                     # cpp17 | cpp20 (extensible)
solution = "sol/model.cpp"             # main contestant entry source
generator = "gen.cpp"                  # optional
validator = "validator.cpp"            # optional but recommended
checker = "chk.cpp"                    # required for custom_checker
grader = "grader.cpp"                  # required for grader
interactor = "int.cpp"                 # required for interactive
extra_sources = []                       # additional .cpp needed for linking
include_dirs = ["."]                    # include search paths
defines = []                             # e.g. ["LOCAL", "DEBUG"]
flags = ["-O2", "-std=c++17"]          # override/extend default compile flags

[run]
time_limit_ms = 1000
memory_limit_mb = 256
process_limit = 1                        # default for non-interactive
wall_time_limit_ms = 3000                # hard upper bound for orchestration

[evaluation]
mode = "token"                          # token | diff | checker | interactive
ignore_trailing_spaces = true
ignore_blank_lines = false
checker_exit_map = { AC = 0, WA = 1, FAIL = 3, PARTIAL = 7 }

[generation]
script = "script.txt"                   # optional
input_pattern = "tests/test{index:02d}.inp"
answer_pattern = "tests/test{index:02d}.out"
validate_after_generate = true
stop_on_validation_error = true

[scoring]
mode = "sum"                            # sum | group-min | custom
full_score = 100
allow_partial = false

[cache]
enabled = true
build_cache = true
run_cache = true
eval_cache = true
interactive_cache = false                # default false for safety

[artifacts]
keep_failed_only = true
keep_transcript = false
log_level = "info"                      # debug | info | warn | error

[extensions]
# reserved for local experimentation, not consumed by core engine
```

## 3.3 Required/Forbidden Matrix by problem.type

1. traditional
- required: build.solution, evaluation.mode in [token, diff]
- forbidden: build.checker, build.interactor, build.grader unless explicitly unused

2. custom_checker
- required: build.solution, build.checker, evaluation.mode=checker
- forbidden: build.interactor unless hybrid mode explicitly supported

3. interactive
- required: build.solution, build.interactor, evaluation.mode=interactive
- required: run.process_limit >= 2
- default: cache.interactive_cache=false

4. grader
- required: build.solution, build.grader
- evaluation.mode can be token/diff/checker
- compile must link grader + solution + extra_sources

## 3.4 Validation Rules

1. schema_version must equal 1 for this RFC.
2. problem.type must be one of supported enum.
3. run.time_limit_ms > 0 and run.memory_limit_mb > 0.
4. evaluation.mode must be compatible with problem.type.
5. checker_exit_map required when evaluation.mode=checker.
6. For interactive:
- run.wall_time_limit_ms must be >= run.time_limit_ms
- process_limit must be >= 2
7. Paths must be repository-relative and normalize to workspace boundaries.
8. Unknown keys in core tables are rejected.

## 4. Examples by Problem Type

## 4.1 Traditional Example

```toml
schema_version = 1

[problem]
code = "prime_check"
name = "Prime Check"
type = "traditional"

[build]
language = "cpp17"
solution = "sol/model.cpp"
generator = "gen.cpp"
validator = "validator.cpp"
flags = ["-O3", "-std=c++17"]

[run]
time_limit_ms = 1000
memory_limit_mb = 256
process_limit = 1
wall_time_limit_ms = 3000

[evaluation]
mode = "token"
ignore_trailing_spaces = true
ignore_blank_lines = false

[generation]
script = "script.txt"
input_pattern = "tests/test{index:02d}.inp"
answer_pattern = "tests/test{index:02d}.out"
validate_after_generate = true
stop_on_validation_error = true

[cache]
enabled = true
build_cache = true
run_cache = true
eval_cache = true
interactive_cache = false
```

## 4.2 Custom Checker Example

```toml
schema_version = 1

[problem]
code = "geometry_area"
name = "Geometry Area"
type = "custom_checker"

[build]
language = "cpp17"
solution = "sol/model.cpp"
checker = "chk.cpp"
validator = "validator.cpp"
flags = ["-O2", "-std=c++17"]

[run]
time_limit_ms = 2000
memory_limit_mb = 256
process_limit = 1
wall_time_limit_ms = 6000

[evaluation]
mode = "checker"
checker_exit_map = { AC = 0, WA = 1, FAIL = 3, PARTIAL = 7 }

[scoring]
mode = "sum"
full_score = 100
allow_partial = true
```

## 4.3 Interactive Example

```toml
schema_version = 1

[problem]
code = "guess_number"
name = "Guess Number"
type = "interactive"

[build]
language = "cpp17"
solution = "sol/model.cpp"
interactor = "int.cpp"
validator = "validator.cpp"
flags = ["-O2", "-std=c++17"]

[run]
time_limit_ms = 1000
memory_limit_mb = 256
process_limit = 2
wall_time_limit_ms = 5000

[evaluation]
mode = "interactive"
checker_exit_map = { AC = 0, WA = 1, FAIL = 3, PARTIAL = 7 }

[cache]
enabled = true
build_cache = true
run_cache = false
eval_cache = false
interactive_cache = false

[artifacts]
keep_failed_only = true
keep_transcript = true
log_level = "info"
```

## 4.4 Grader (IOI Two-step) Example

```toml
schema_version = 1

[problem]
code = "ioi_sort"
name = "IOI Sort"
type = "grader"

[build]
language = "cpp17"
solution = "sol/model.cpp"
grader = "grader.cpp"
extra_sources = ["lib/helper.cpp"]
include_dirs = [".", "lib"]
flags = ["-O2", "-std=c++17"]

[run]
time_limit_ms = 2000
memory_limit_mb = 512
process_limit = 1
wall_time_limit_ms = 6000

[evaluation]
mode = "token"
ignore_trailing_spaces = true
ignore_blank_lines = false

[scoring]
mode = "group-min"
full_score = 100
allow_partial = true
```

## 5. Current-State Gap Analysis

Current implementation strengths:

1. Existing compile utility and caching
2. Existing evaluate flow and batch mode
3. Existing phase wrappers and deterministic cache improvements

Current implementation gaps versus schema-driven engine:

1. No canonical schema parser with strict validation
2. No type-specific strategy factory
3. Interactive runner not integrated into core
4. Checker/grader not first-class in one entrypoint
5. Cache graph not yet modeled by formal dependency policy

## 6. Migration Checklist by Sprint

Each sprint below assumes 1-2 engineers full-time equivalent. Adjust duration by team size.

## Sprint 0: Alignment and Baseline (3-5 days)

Tasks:

1. Freeze RFC-001, RFC-002, RFC-003 as architecture baseline.
2. Add architecture decision log and ownership map.
3. Define compatibility policy with existing CLI commands.

Deliverables:

1. Approved schema v1
2. Migration branch and test baseline snapshot

Exit criteria:

1. Team sign-off on schema and rollout policy

## Sprint 1: Schema Loader and Validation Core (1 week)

Tasks:

1. Implement parser for problem.toml.
2. Implement strict validator with precise error messages.
3. Add schema compatibility checks by problem.type.
4. Add unit tests for valid/invalid configs.

Deliverables:

1. spec module with ProblemSpec model
2. validation report format

Exit criteria:

1. 100% passing validation tests for provided fixtures
2. Unknown key rejection confirmed

## Sprint 2: Strategy Interfaces and Traditional Pipeline (1 week)

Tasks:

1. Extract CompilerStrategy, RunnerStrategy, EvaluatorStrategy interfaces.
2. Port current traditional flow into TraditionalPipeline.
3. Add PipelineFactory with type=traditional route.
4. Keep existing evaluate CLI as compatibility wrapper.

Deliverables:

1. engine skeleton with factory and strategy wiring
2. feature parity for traditional mode

Exit criteria:

1. Existing traditional tests pass with new engine path
2. Legacy and new outputs match on regression suite

## Sprint 3: Custom Checker Pipeline (1 week)

Tasks:

1. Add CheckerEvaluator.
2. Add checker exit-code mapping config support.
3. Add partial scoring support in verdict model.
4. Add fixtures for AC/WA/FAIL/PARTIAL checker outcomes.

Deliverables:

1. custom_checker route in PipelineFactory
2. verdict mapping integration

Exit criteria:

1. Checker test suite stable and deterministic
2. Diagnostics include checker stderr summary

## Sprint 4: Grader Build Strategy (1 week)

Tasks:

1. Implement multi-source compile/link (grader + solution + extras).
2. Add include_dirs/defines support.
3. Add compile cache key extensions for multi-source build graph.

Deliverables:

1. grader route with deterministic build artifacts

Exit criteria:

1. IOI-style fixture compiles and evaluates correctly
2. Cache invalidates correctly when grader changes

## Sprint 5: Interactive Runner (2 weeks)

Tasks:

1. Implement runner_interactive module per RFC-002.
2. Add IPC supervision, idle timeout, kill-tree cleanup.
3. Add transcript artifacts.
4. Add stress tests for deadlock and race conditions.

Deliverables:

1. interactive route in PipelineFactory
2. reproducible event logs for failed runs

Exit criteria:

1. Interactive reliability suite passes on Windows and Linux
2. No leaked child process across failure scenarios

## Sprint 6: Unified Cache Graph and Artifact Policy (1 week)

Tasks:

1. Consolidate build/run/eval caches into dependency-aware key graph.
2. Add cache controls: no-cache, rebuild, purge.
3. Add cache integrity checks and corruption recovery.

Deliverables:

1. stable cache schema and migration helper

Exit criteria:

1. Cache hit/miss behavior predictable and documented
2. Recovery path works on corrupted cache file

## Sprint 7: Wrapper Convergence and Documentation (1 week)

Tasks:

1. Convert existing scripts to thin wrappers over engine entrypoint.
2. Update README and command docs.
3. Add migration guide from legacy commands.
4. Add CI checks for schema fixtures and integration tests.

Deliverables:

1. one canonical execution path
2. deprecation notice for legacy direct code paths

Exit criteria:

1. All existing workflows still callable via old commands
2. New engine used internally by default

## Sprint 8: Hardening and Release (1 week)

Tasks:

1. Performance profiling and bottleneck fixes.
2. Flake analysis and retry policy for unstable tests.
3. Final acceptance test and release checklist.

Deliverables:

1. release candidate and rollback plan

Exit criteria:

1. Release gates all green
2. rollback drills verified

## 7. Risk Register and Mitigation

1. Risk: migration stalls due to dual-path complexity
- Mitigation: hard deadline to remove legacy core path after Sprint 7

2. Risk: false cache hits from incomplete key graph
- Mitigation: include toolchain id, flags, and policy hash in key

3. Risk: interactive instability on Windows
- Mitigation: dedicated platform parity suite and process-leak checks

4. Risk: checker semantics mismatch across tasks
- Mitigation: make checker_exit_map mandatory for checker/interactive mode

## 8. Recommended Team Working Agreement

1. No new feature merged without schema field ownership.
2. No direct path-based heuristics in engine modules.
3. Every new problem.type behavior must be strategy-driven.
4. Every cache key change must include migration note.

## 9. Acceptance Checklist (Program-level)

A migration is complete when:

1. problem.toml fully drives build, run, evaluate behavior.
2. All four problem types are supported by the same engine entrypoint.
3. Legacy scripts call into the engine instead of owning core logic.
4. Checker and interactive verdicts are deterministic and test-covered.
5. Documentation and examples are sufficient for new contributors.

## 10. Appendix: Minimal problem.toml Templates

Template A (traditional):

```toml
schema_version = 1

[problem]
code = "template_traditional"
name = "Template Traditional"
type = "traditional"

[build]
language = "cpp17"
solution = "sol/model.cpp"

[run]
time_limit_ms = 1000
memory_limit_mb = 256
process_limit = 1
wall_time_limit_ms = 3000

[evaluation]
mode = "token"
ignore_trailing_spaces = true
ignore_blank_lines = false
```

Template B (interactive):

```toml
schema_version = 1

[problem]
code = "template_interactive"
name = "Template Interactive"
type = "interactive"

[build]
language = "cpp17"
solution = "sol/model.cpp"
interactor = "int.cpp"

[run]
time_limit_ms = 1000
memory_limit_mb = 256
process_limit = 2
wall_time_limit_ms = 5000

[evaluation]
mode = "interactive"
checker_exit_map = { AC = 0, WA = 1, FAIL = 3, PARTIAL = 7 }

[cache]
enabled = true
interactive_cache = false
```
