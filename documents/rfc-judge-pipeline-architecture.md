# RFC: Configuration-Driven Judge Pipeline for CP Tooling

- Status: Draft
- Author: Project Team
- Date: 2026-04-13
- Target Version: v2 CLI Framework

## 1. Summary

This RFC proposes a full architectural migration from sequential scripting to a configuration-driven, strategy-based judge pipeline supporting:

1. Traditional problems
2. Custom checker problems
3. Interactive problems
4. IOI-style grader/two-step problems

The design centers around a manifest contract (`problem.toml`) and separates judge flow into 3 extensible phases:

1. Build Phase
2. Execution Phase
3. Evaluation Phase

This RFC also includes critical review: limitations, trade-offs, and failure modes of the proposed architecture.

## 2. Motivation

Current tooling works for traditional stdin/stdout + diff/token workflows, but hard-coded flow creates structural breakpoints for:

1. Interactive IPC process orchestration
2. Checker-based verdict semantics
3. Grader linkage model (multi-source build)
4. Partial scoring and richer verdict data
5. Deterministic reusable caching across phase boundaries

Without architecture-level abstraction, each new problem type forces ad-hoc branching and duplicated control logic.

## 3. Goals and Non-goals

### 3.1 Goals

1. Introduce one canonical problem manifest as source of truth
2. Support multiple problem classes without forking core engine
3. Keep pipeline behavior deterministic and cacheable
4. Allow strict compatibility with testlib-style checker/interactor exit semantics
5. Preserve current CLI usability while enabling gradual migration

### 3.2 Non-goals

1. Re-implement a full online judge sandbox in v1 (namespaces/cgroups/seccomp)
2. Add distributed judge workers in this phase
3. Replace all shell wrappers immediately (backward compatibility retained)

## 3.3 Platform Support Policy

1. Core non-interactive pipeline (config validation, build, generate, validate, solve, checker evaluation) must support Windows native and Linux.
2. Interactive pipeline is Linux/WSL2-first for release acceptance in v1.
3. Windows interactive support is best-effort and tracked separately from release-blocking gates.
4. Git Bash on Windows is valid for smoke-testing wrappers and CLI wiring only.

## 4. Proposed Manifest Contract

File: `problem.toml`

```toml
[problem]
name = "a_plus_b"
type = "interactive" # traditional | custom_checker | interactive | grader
time_limit = 1.0
memory_limit = 256

[build]
generator = "gen.cpp"
validator = "validator.cpp"
checker = "chk.cpp"      # required for custom_checker
interactor = "int.cpp"   # required for interactive
grader = "grader.cpp"    # required for grader
solution_headers = ["solution.h"]

[evaluation]
mode = "checker"          # diff | token | checker
allow_partial = true
```

Validation rules:

1. `type=custom_checker` requires `build.checker`
2. `type=interactive` requires `build.interactor`
3. `type=grader` requires `build.grader`
4. `evaluation.mode=checker` requires compiled checker/interactor path in selected pipeline
5. Reject unknown keys to prevent silent misconfiguration

## 5. Architecture Overview

## 5.1 Core Components

1. `ProblemSpecLoader`
- Parse and validate `problem.toml`
- Produce normalized immutable `ProblemSpec`

2. `Compiler`
- Compile one or more source units into targets
- Hash-based artifact caching
- Captures build metadata for invalidation

3. `Runner`
- Execute target(s) with time/memory governance
- Strategy per problem type

4. `Evaluator`
- Convert execution artifacts to verdict/score
- Strategy per evaluation mode

5. `PipelineEngine`
- Orchestrates build -> run -> evaluate
- Owns shared cache graph and logging policy

## 5.2 Strategy Interfaces

```python
class CompilerStrategy:
    def compile(self, target: BuildTarget) -> BuildArtifact: ...

class RunnerStrategy:
    def run(self, ctx: RunContext) -> RunResult: ...

class EvaluatorStrategy:
    def evaluate(self, ctx: EvalContext) -> VerdictResult: ...
```

Factory:

1. `PipelineFactory.from_spec(spec)`
2. Selects strategy bundle by `problem.type` + `evaluation.mode`

## 6. Pipelines by Problem Type

## 6.1 Traditional

1. Build: compile solution binary
2. Run: `sol < in > out`
3. Evaluate: diff/token comparator

## 6.2 Custom Checker

1. Build: compile solution + checker
2. Run: `sol < in > out`
3. Evaluate: `checker in out ans`
4. Exit code mapping (testlib conventions):
- `0`: AC
- `1`: WA
- `3`: FAIL/IE
- `7`: PARTIAL/PE (configurable mapping)

## 6.3 Grader / Two-step / Function Signature

1. Build: link `grader.cpp + user_solution.cpp` into one executable
2. Run: standard stdin/stdout unless manifest defines checker mode
3. Evaluate: diff/token or checker (manifest-driven)

## 6.4 Interactive

1. Build: compile solution + interactor
2. Run:
- Create two directional pipes
- Wire solution stdout -> interactor stdin
- Wire interactor stdout -> solution stdin
- Interactor receives file args (`in`, `ans`/log) per policy
3. Evaluate:
- Primary source: interactor exit code
- Secondary source: runtime exception and timeout channels

## 7. Caching and Determinism

## 7.1 Build Cache Key

Hash tuple:

1. source file hashes
2. compiler commandline/flags
3. include dependency fingerprint (optional v2)
4. platform + toolchain id

## 7.2 Run/Eval Cache Key

Per test and strategy:

1. input hash
2. solution binary hash
3. checker/interactor binary hash (if present)
4. evaluation mode signature
5. relevant runtime constraints (time limit, strictness flags)

Cache hit policies:

1. Validate may skip only when deterministic key fully matches and previous status is definitive
2. Solve may skip only when output artifact hash still matches cached metadata
3. Any mismatch triggers full rerun and cache rewrite

## 8. Validator Policy

Mandatory gate after generation:

1. Generated input must pass validator before entering evaluation pool
2. If validator fails:
- mark testcase invalid
- do not proceed to solve/evaluate for that test
- configurable behavior: fail-fast or continue collecting errors

## 9. Verdict and Result Model

Standardized verdict object:

```json
{
  "status": "AC|WA|TLE|MLE|RTE|IE|PARTIAL",
  "score": 0,
  "time_ms": 12.3,
  "memory_mb": 4.8,
  "message": "checker detail",
  "artifacts": {
    "input": "tests/test01.inp",
    "output": "tests/test01.out",
    "stderr": "logs/test01.stderr"
  }
}
```

Rationale:

1. Required for partial scoring
2. Required for checker/interactor rich diagnostics
3. Enables stable machine-readable reporting

## 10. Migration Plan

## Phase 1 (Low-risk extraction)

1. Introduce `EvaluatorStrategy` interface
2. Keep old diff behavior as `DiffEvaluator`
3. Add `CheckerEvaluator`
4. Keep existing CLI flags unchanged

## Phase 2 (Manifest bootstrapping)

1. Add `problem.toml` parser and strict validation
2. Build `PipelineFactory`
3. Route existing flow through factory with default `traditional`

## Phase 3 (Build graph expansion)

1. Multi-source compile requests for grader
2. Normalize build artifacts and cache keys

## Phase 4 (Interactive isolation)

1. Implement `InteractiveRunner` in dedicated module
2. Stress test deadlock scenarios
3. Add watchdog and timeout accounting for both processes

## Phase 5 (Convergence and deprecation)

1. Move shell scripts to thin wrappers calling pipeline engine
2. Deprecate legacy hardcoded evaluation path
3. Freeze stable cache schema and reporting format

## 11. Critical Review: Weaknesses and Limitations

## 11.1 Manifest Risks

1. Single-point-of-failure: malformed `problem.toml` blocks all operations
2. Schema drift risk across versions without explicit `schema_version`
3. Teams may create non-portable local fields unless extension namespace is controlled

Mitigation:

1. Add schema versioning
2. Strict validation with actionable diagnostics
3. Reserve `[x-*]` namespace for local extension keys

## 11.2 Caching Risks

1. False cache hits if key omits hidden dependencies (headers, env vars, checker data files)
2. Stale artifacts when compiler version changes but key lacks toolchain fingerprint
3. Cache complexity can mask correctness bugs

Mitigation:

1. Expand cache key to include toolchain id and critical env
2. Optional deep dependency scan for C++ include graph
3. Provide `--no-cache` and `--rebuild` for deterministic debugging

## 11.3 Interactive Complexity Risks

1. IPC deadlocks due to buffering and unflushed streams
2. Platform-specific process/pipe behavior differences
3. Hard-to-debug race conditions in timeout and termination logic

Mitigation:

1. Use explicit non-blocking I/O or supervised threading model
2. Add trace logging mode with transcript capture
3. Kill-tree policy and deterministic cleanup on timeout

## 11.4 Checker Semantics Ambiguity

1. Exit code mapping differs between checker implementations
2. `7` may represent partial or format/presentation depending policy
3. Custom checker stderr messages may be inconsistent

Mitigation:

1. Make checker mapping configurable in manifest
2. Standardize checker output contract in docs
3. Add normalization layer for checker diagnostics

## 11.5 Migration Cost

1. Refactor touches nearly every module
2. Temporary dual-path support increases maintenance burden
3. Existing scripts may diverge from core engine behavior

Mitigation:

1. Thin wrappers only, no duplicated business logic
2. Incremental migration with compatibility tests
3. Set sunset date for legacy path

## 12. Open Questions

1. Should partial scoring be first-class in v1 or deferred behind feature flag?
2. Should token comparator remain default for traditional or require explicit mode?
3. Do we standardize on TOML only, or support both TOML and YAML?
4. How strict should fail-fast policy be for invalid test generation batch?

## 13. Acceptance Criteria

This RFC is considered implemented when:

1. A project with `problem.toml` can run all supported problem types via one CLI entrypoint
2. Build/Run/Eval behavior is selected from config, not filename heuristics
3. Checker and interactive verdict mapping is deterministic and test-covered
4. Cross-phase cache invalidation is correct under source, input, and toolchain changes
5. Legacy scripts become wrappers over the same core engine
6. Windows native support is verified for non-interactive pipelines, while interactive release gates remain Linux/WSL2-first

## 14. Suggested Next Steps (Execution)

1. Freeze `problem.toml` schema v1
2. Create module skeletons: `spec`, `compiler`, `runner`, `evaluator`, `engine`
3. Port current diff pipeline into `TraditionalPipeline`
4. Add `CustomCheckerPipeline`
5. Add grader build strategy
6. Develop interactive runner in isolation with stress test harness

---

This RFC intentionally prioritizes architectural integrity over short-term scripting convenience. The main trade-off is higher initial complexity in exchange for long-term extensibility and correctness across judge paradigms.
