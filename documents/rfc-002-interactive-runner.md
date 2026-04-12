# RFC-002: Interactive Runner Subsystem

- Status: Draft
- Date: 2026-04-13
- Depends on: RFC-001 (Configuration-Driven Judge Pipeline)
- Scope: Interactive problem execution model, IPC orchestration, reliability guarantees

## 1. Summary

This RFC defines the Interactive Runner subsystem for the new judge engine. The subsystem executes two concurrent programs:

1. Contestant solution process
2. Interactor process

They communicate through bidirectional pipes while the judge supervises runtime, resources, process lifecycle, and verdict mapping.

The design goal is to provide deterministic, debuggable, and platform-consistent behavior for interactive tasks while integrating with the strategy/factory architecture proposed in RFC-001.

## 1.1 Platform Support Policy (Normative)

1. Interactive v1 acceptance target is Linux/WSL2.
2. Windows native support for interactive is best-effort and is not a release blocker.
3. Core non-interactive flows (`check-config`, compile, generate, validate, solve, checker mode) must remain fully supported on Windows native.
4. Git Bash on Windows is a smoke-test environment only for CLI wiring, not an interactive parity target.

## 2. Problem Statement

Traditional runner assumptions no longer hold in interactive tasks:

1. There is no single linear stdin->stdout stream from static input to static output.
2. Both processes can block each other, causing deadlock.
3. Verdict authority often belongs to interactor exit semantics.
4. Time accounting must include both processes and interaction overhead.
5. Failure modes are asynchronous and race-prone.

Therefore, interactive execution must be an isolated first-class module, not an extension of the traditional runner.

## 3. Goals and Non-goals

### 3.1 Goals

1. Run solution and interactor concurrently with controlled IPC wiring.
2. Detect and classify deadlock, timeout, crash, protocol violation, and judge internal errors.
3. Preserve transcript and diagnostics for reproducible debugging.
4. Map interactor/checker semantics into standardized verdict model.
5. Support deterministic replay for a given test seed/input snapshot.

### 3.2 Non-goals

1. Full process sandboxing (seccomp/cgroup namespace isolation) in this phase.
2. Distributed multi-node orchestration.
3. Real-time GUI visualization.

## 4. Terminology

1. `SOL`: contestant process.
2. `INT`: interactor process.
3. `P_sol_to_int`: byte stream from SOL stdout to INT stdin.
4. `P_int_to_sol`: byte stream from INT stdout to SOL stdin.
5. `Transcript`: captured interaction stream and event timeline.

## 5. High-level Architecture

The interactive runner consists of:

1. `InteractiveRunnerStrategy`
2. `PipeBroker`
3. `ProcessSupervisor`
4. `TimeoutController`
5. `TranscriptCollector`
6. `VerdictMapper`

## 5.1 Shared State Contract (Critical)

To avoid drift between Build/Run/Eval layers, runner state must be passed through one immutable execution context.

Required shared fields:

1. `build_fingerprint` (hash of binaries + flags + toolchain)
2. `test_fingerprint` (input hash + answer hash when available)
3. `policy_fingerprint` (timeout, memory, verdict mapping policy)
4. `session_id` and `test_id`
5. `artifact_dir`

Rule:

1. Run and evaluator modules are forbidden from recomputing policy from local defaults.
2. Verdict decisions must only use state inside this context.

Execution flow:

1. Build phase outputs `sol_exec` and `interactor_exec` artifacts.
2. Runner initializes IPC channels.
3. Supervisor starts both processes and tracks state transitions.
4. Timeout controller enforces per-process and global constraints.
5. Transcript collector writes event/log artifacts.
6. Runner terminates and resolves verdict from combined signals.

## 6. Process Wiring Contract

## 6.1 Invocation Contract

Interactor command (baseline):

```text
int_exec <input_file> <answer_file>
```

Solution command (baseline):

```text
sol_exec
```

IPC mapping:

1. `SOL.stdout` -> `INT.stdin`
2. `INT.stdout` -> `SOL.stdin`
3. `INT.stderr` captured to `interactor.stderr.log`
4. `SOL.stderr` captured to `solution.stderr.log`

Optional extension keys from `problem.toml`:

1. extra args for interactor
2. separate transcript policy
3. custom exit code mapping

## 6.2 Buffering and Flush Policy

Critical reliability rule:

1. Interactive protocols require timely flush from both programs.
2. Runner must use unbuffered binary pipes and actively pump streams.
3. `subprocess.communicate()` is forbidden for interactive mode because it waits for process termination and cannot prevent bidirectional pipe deadlock.
4. Idle detection uses byte activity timestamps, not process liveness only.

## 6.3 Async Non-blocking IO Requirement

The runner must not rely on blocking read/write loops.

Required model:

1. Use `asyncio` subprocess + stream tasks (or equivalent event loop abstraction).
2. Run 4 concurrent tasks at minimum:
- SOL stdout -> INT stdin pump
- INT stdout -> SOL stdin pump
- SOL stderr drain
- INT stderr drain
3. Add bounded write queue and backpressure handling.
4. Track last-activity timestamp in each pump task.
5. Each pump must be cancel-safe and flush-safe on teardown.

Failure handling:

1. Any pump task exception escalates to `RUNNER_INTERNAL_ERROR` and triggers kill-tree.
2. If one side closes stdout, close peer stdin gracefully to avoid hanging writers.
3. The engine must prefer streaming reads/writes over whole-buffer collection.

## 7. Timeout and Resource Model

Time controls:

1. `time_limit_solution_ms`
2. `time_limit_interactor_ms`
3. `wall_clock_limit_ms` (global)
4. `idle_timeout_ms` (no I/O activity threshold)
5. `interactor_grace_ms` (post-solution or post-timeout drain window)

Memory controls:

1. per-process RSS monitoring (best-effort in this phase)
2. global memory cap optional (soft-fail warning)
3. aggregate memory policy (SOL RSS + INT RSS) compared against configured limit

Aggregate limit rule:

1. For interactive tasks, default enforcement uses combined RSS.
2. Config can opt into split limits (`memory_limit_sol_mb`, `memory_limit_int_mb`) only when explicitly set.

Termination policy:

1. On hard timeout of either process, kill both process trees.
2. On protocol deadlock (idle timeout), kill both and classify as protocol failure or TLE by policy.
3. Always perform deterministic cleanup and close all open handles.
4. The interactor has an explicit budget and may be killed even if the solution is still within budget when the combined wall clock limit is exceeded.

## 8. Verdict Resolution Policy

Primary principle:

1. Interactor is the authority when it exits with known checker semantics.

Suggested mapping defaults:

1. `INT exit 0` and SOL healthy completion -> AC
2. `INT exit 1` -> WA
3. `INT exit 7` -> PARTIAL
4. `INT exit 3` -> IE/FAIL (judge-side or checker failure)
5. SOL crash before valid interactor accept -> RTE
6. timeout breach -> TLE
7. idle deadlock -> TLE or IE (configurable)

Conflict handling examples:

1. INT says AC but SOL already crashed unexpectedly: classify as RTE unless policy explicitly trusts INT final status.
2. INT crashes with internal assert: IE regardless of SOL output.

## 8.1 Verdict Translator Module (Mandatory)

The engine must include a dedicated `VerdictTranslator`, not inline mapping logic inside runner/evaluator.

Responsibilities:

1. Translate checker/interactor exit codes into normalized verdicts.
2. Apply precedence table when multiple failure signals occur.
3. Preserve raw diagnostics for UI/debug.

Default precedence order (highest first):

1. `RUNNER_INTERNAL_ERROR`
2. hard resource breach (`MLE`, hard timeout)
3. process crash (`RTE`)
4. interactor/checker semantic verdict (`AC/WA/PARTIAL/FAIL`)
5. fallback `IE`

This precedence prevents contradictory outcomes such as AC after crash.

## 9. Transcript and Debug Artifacts

Each test run should persist:

1. `runner.events.jsonl` (canonical transcript/event stream)
2. `solution.stderr.log`
3. `interactor.stderr.log`
4. `transcript.txt` (optional human-readable export)

Recommended export formats:

1. JSONL for machine-readable replay and grep-friendly debugging
2. Optional text transcript for human inspection only

Minimum event fields:

1. monotonic timestamp
2. source (`SOL|INT|RUNNER`)
3. event type (`spawn|io|exit|timeout|kill`)
4. byte counters and process ids

Retention policy:

1. Keep artifacts for failed tests by default.
2. Optional `--keep-artifacts all` for deep debugging.

## 10. Caching Policy for Interactive

Default stance:

1. Do not reuse interactive run outputs as final verdict cache by default.

Rationale:

1. Interactors may contain nondeterminism.
2. Runtime scheduling and timing races can alter behavior.

Optional deterministic mode (opt-in):

1. Allow caching only when manifest marks interactor deterministic.
2. Cache key includes:
- input hash
- sol binary hash
- interactor binary hash
- runner policy hash (timeouts, mapping)
- environment fingerprint

## 11. API Proposal

```python
class InteractiveRunnerStrategy(RunnerStrategy):
    def run(self, ctx: InteractiveRunContext) -> InteractiveRunResult: ...

@dataclass
class InteractiveRunContext:
    test_id: str
    input_file: Path
    answer_file: Path
    sol_exec: Path
    interactor_exec: Path
    limits: Limits
    policy: InteractivePolicy

@dataclass
class InteractiveRunResult:
    status: str
    time_ms_sol: float
    time_ms_int: float
    wall_time_ms: float
    bytes_sol_to_int: int
    bytes_int_to_sol: int
    sol_exit_code: int | None
    int_exit_code: int | None
    artifact_dir: Path
    message: str
```

## 12. Failure Taxonomy

1. `SOL_START_FAIL`
2. `INT_START_FAIL`
3. `SOL_TIMEOUT`
4. `INT_TIMEOUT`
5. `IDLE_DEADLOCK`
6. `PIPE_BROKEN`
7. `INT_PROTOCOL_REJECT`
8. `SOL_RUNTIME_ERROR`
9. `INT_INTERNAL_ERROR`
10. `RUNNER_INTERNAL_ERROR`

This taxonomy maps to public verdicts while preserving internal diagnostics.

## 13. Testing Strategy

Mandatory test matrix:

1. SOL flushes correctly -> AC path
2. SOL forgets flush -> deadlock detection
3. INT exits WA with message
4. SOL crashes early (segfault/non-zero)
5. INT crashes early
6. SOL infinite loop with no output
7. INT infinite wait
8. Large message bursts across both pipes
9. Repeated runs for stability (flake detection)
10. Combined RSS breach (SOL + INT) while each process alone stays below limit
11. Contradictory signal test (INT=AC but SOL crash) to verify precedence table
12. Long-output burst test where SOL writes >64KB before first read to force pipe backpressure
13. Long-think test where INT delays response to verify idle timeout vs wall-clock timeout separation

Cross-platform validation:

1. Windows named/anonymous pipe behavior
2. Linux/macOS pipe buffering and signal handling
3. Linux/WSL2 reliability suite is mandatory for release gating
4. Windows interactive suite is best-effort smoke/stability coverage and reports non-blocking issues separately

## 14. Migration Plan

1. Implement module `runner_interactive.py` isolated from existing evaluate flow.
2. Add synthetic local stress suite for deadlock/timeouts.
3. Integrate into `PipelineFactory` for `problem.type=interactive`.
4. Add CLI `judge run --type interactive` compatibility shim.
5. Keep legacy runner untouched until parity tests pass.
6. Add `judge check-config` before any interactive execution to validate manifest and required binaries.
7. Add `judge dry-run` to validate wiring without persisting cache/output artifacts.
8. Keep a temporary `--legacy` fallback only during migration, not as the final default path.

## 15. Critical Review: Weaknesses and Limitations

## 15.1 Complexity Explosion

Risk:

1. Interactive supervision code can become the most complex subsystem.
2. Hard to reason about race conditions without strict state machine design.

Consequence:

1. Higher maintenance burden and slower onboarding.

Mitigation:

1. Explicit finite state machine for runner lifecycle.
2. Structured event logs and deterministic integration tests.

## 15.2 Platform Divergence

Risk:

1. Pipe semantics and process termination differ on Windows vs POSIX.
2. Same workload may produce different timing behavior.

Consequence:

1. Verdict inconsistency across developer machines.

Mitigation:

1. Prefer policy based on wall clock + activity windows over fragile micro-timing assumptions.
2. Add platform abstraction layer with targeted tests.
3. Keep release gate on Linux/WSL2 and treat Windows interactive failures as tracked, non-blocking defects unless they affect non-interactive paths.

## 15.3 False Deadlock Signals

Risk:

1. Protocols with long think time can trigger idle timeout falsely.

Consequence:

1. Incorrect TLE/deadlock verdict.

Mitigation:

1. Separate idle timeout from hard wall timeout.
2. Expose per-problem tuning in manifest.

## 15.4 Verdict Ambiguity

Risk:

1. SOL and INT can fail nearly simultaneously with contradictory signals.

Consequence:

1. Non-deterministic classification and hard debugging.

Mitigation:

1. Define strict precedence table in policy.
2. Persist full timeline and both exit reasons.

## 15.5 Security Gap

Risk:

1. Without sandboxing, malicious solution/interactor can abuse host resources.

Consequence:

1. Unsafe local execution for untrusted code.

Mitigation:

1. Explicitly document trust model for v1.
2. Plan sandbox RFC as follow-up (RFC-003).

## 16. Open Questions

1. Should interactor always be authoritative, or can policy allow SOL-dominant precedence on conflicts?
2. Should partial score support be mandatory in interactive v1?
3. Should transcript format be binary framed or human-readable text-first?
4. Should deterministic interactive caching be disabled entirely in first release?

## 17. Acceptance Criteria

RFC-002 is accepted when:

1. Interactive runs are supported via configuration and strategy factory.
2. Deadlock/timeout/crash taxonomy is reproducible in tests.
3. Verdict mapping is deterministic and documented.
4. Artifact logs are sufficient to replay and debug failures.
5. Cross-platform behavior passes baseline parity suite.

## 18. Suggested Follow-up Work

1. RFC-004: Sandbox and isolation model
2. RFC-005: Grader/two-step ABI contract and multi-language support
3. RFC-006: Scoring model and subtask aggregation semantics

---

This RFC intentionally favors correctness and observability over minimal code size. For interactive judging, operational reliability is more valuable than short-term implementation speed.
