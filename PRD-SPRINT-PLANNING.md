# Sprint Plan: Toy Model of Argumentation-Based Deliberation

> **Development need:** Build a rule-based ABM of deliberation that bridges DeGroot-style computational models with the empirically grounded deliberation literature, implements classic mini-public formats, computes DRI, and enables scaffolded factorial experiments over institutional parameters. Pure modeling, OOP, ambitious and modular. Architecture must support future swap of rule-based engines for LLM agents and random initialization for ANES survey data, via a principal-agent relationship where the engine pursues the principal's interests through honest deliberation.
> **Date:** 2026-04-14
> **Status:** DRAFT -- Pending review before execution
> **Sprint location:** `prospectus-work/sprint-01-toy-deliberation/`

---

## 1. Situation Assessment

### Current State

Three prototype implementations exist in the repo, none of which meets the sprint goal:

**`prospectus-work/llm-deliberation/deliberation_ABM.py`** (145 lines). Agents hold ranked preference orderings over 5 policies. Persuasion is threshold-gated: if `speaker.persuasion_power >= listener.persuasion_threshold`, the listener moves the supported policy to rank 1 and the opposed policy to last. No argument content, no considerations, no DRI, no institutional protocols, no structured output. The `Simulation` class runs rounds where every agent speaks to every other agent -- a complete-graph plenary with no subgroup structure. The `Analysis` class computes rank distributions but no relational metrics. Hard-coded magic numbers throughout (top 2 / bottom 2 selection, policy set `['A','B','C','D','E']`). This is a sketch, not a model.

**`prospectus-work/opinion-abm/js/engine/`** (5 JS files). A browser-based simulator with a `SimulationEngine` class (176 lines in `deliberation.js`). Agents are scalar opinions in [0,1]. Update is homophilic bounded-confidence with stochastic persuasion: a convener selects the k-1 nearest agents, then pairwise weighted averaging within bounded confidence. Tracks variance/skewness/kurtosis over time. Clean engine/viz separation. No argument content, no protocols, no DRI, no factorial experiments. The `conductVote` function splits agents at the largest opinion gap -- a novel heuristic but not grounded in the deliberation literature.

**`prospectus-work/project-olympus/.../olympus_scaffold_updated/`**. Well-structured ABM scaffold: `pyproject.toml` with setuptools, `src/olympus/` layout, frozen dataclasses for parameters (`CarbonParams`, `ClimateParams`), structured JSON logging (`logging_utils.py`), pytest, ruff, mypy, Makefile, Hydra config. Only the climate module (`twobox.py`, 135 lines) is substantively implemented. Agent/diplomacy/engine/evolution packages are empty placeholders. This scaffold is the best structural precedent for the new package.

**Literature base** is fully developed: 27 papers extracted into `lit-ralph/extractions.json` (5,291 lines), synthesized into three briefs under `lit-ralph/briefs/`. The briefs establish:
- DRI as the primary outcome metric (Niemeyer et al. 2024: +0.113, p<0.01)
- Group building as the dominant institutional predictor (0.076 per level, R^2=0.166)
- Bayesian updating as the micro-theory of opinion change (Barabas 2004: +0.10 knowledge, +0.14 opinion on consensual issues)
- Symmetric-argument impossibility as a ceiling constraint (Jackman & Sniderman 2006)
- Consensus probability scaling with group size (K&B 2021: 1.00 at n=3, 0.00 at n=15)
- Mixed dyadic + deliberative dynamics as the strongest ABM template (Butler et al. 2019: R^2 for Var(o)=0.931, ir=0.958)
- Polarization base rates by design condition (Caluwaerts et al. 2023: 54.8% depolarize in heterogeneous, 63.6% polarize in homogeneous)

### Problem Statement

The gap between the existing prototypes and the research goal is structural, not incremental. The prototypes model opinion dynamics (scalar updating), not deliberation (argument exchange, consideration weighing, intersubjective consistency). Brief 01 calls this the "content bottleneck": every prior ABM represents arguments as semantics-free tokens. The current `deliberation_ABM.py` inherits this limitation -- its agents move policy rankings but have no reasons for doing so. DRI cannot be computed without a consideration layer, because DRI measures the correlation between pairwise agreement on considerations and pairwise agreement on preferences. Without considerations, there is no DRI. Without DRI, there is no calibration target against the strongest empirical benchmark in the literature.

The sprint must:
1. Give agents internal structure rich enough to compute DRI (considerations + preferences)
2. Implement composable cognitive engines so DeGroot-to-deliberation is an explicit, testable spectrum
3. Encode mini-public formats as protocol objects that determine who speaks when, in what groups, under what rules
4. Build a factorial experiment runner that crosses institutional parameters
5. Reproduce four empirical calibration targets as benchmark tests
6. Plant the architectural swap points for LLM engines and ANES survey initialization without implementing either

### Constraints & Risks

**Group size scaling.** K&B 2021 show consensus probability drops to 0 at n=15 without subgroups. A 100-agent plenary will collapse. All protocols must support subgroup decomposition, and the experiment runner must treat group size as a first-order variable.

**DRI computation cost.** DRI requires pairwise comparisons across all agent pairs: O(n^2) pairs times O(k) considerations per comparison, where k is the size of the shared consideration set. At n=100, k=20, this is 4,950 pairs x 20 = 99,000 comparisons per measurement. Acceptable for a toy model but must be kept in mind for metric computation frequency.

**Calibration ambiguity.** The benchmark targets come from human experiments. Rule-based agents are not humans. The benchmarks constrain the *direction* and *order of magnitude* of effects, not exact reproduction. Acceptance criteria should use ranges, not point estimates.

**No external dependencies beyond numpy/scipy.** The model must be self-contained, runnable without LLMs, APIs, or heavy frameworks. This is a rule-based toy model. Numpy for linear algebra, scipy.stats for correlation computations, dataclasses for parameter objects. No pandas, no networkx, no hydra (those add complexity without benefit at this stage).

---

## 2. Target State

### Architecture After Changes

A new Python package `agora` under `prospectus-work/sprint-01-toy-deliberation/src/agora/`, installable via `pip install -e .`, with the following module structure:

```
prospectus-work/sprint-01-toy-deliberation/
|-- SPRINT.md                              # Sprint overview
|-- story-01-foundations/STORY.md          # Agent, Consideration, ArgumentPool, PrincipalProfile
|-- story-02-engines/STORY.md             # CognitiveEngine hierarchy: voice/evaluate/reflect
|-- story-03-metrics/STORY.md             # DRI, alpha-fairness, distributional, procedural
|-- story-04-facilitation/STORY.md        # Moderator, group building, group assignment
|-- story-05-protocols/STORY.md           # Plenary, Jury, Assembly, TownHall, Committee
|-- story-06-experiments/STORY.md         # Config, FactorialDesign, Runner, ScenarioGenerator, IO
|-- story-07-benchmarks/STORY.md          # Four calibration targets as executable tests
|-- src/
|   `-- agora/
|       |-- __init__.py
|       |-- agents.py                     # Agent, AgentPopulation, PrincipalProfile
|       |-- considerations.py             # Consideration, ArgumentPool, AttackGraph
|       |-- engines.py                    # CognitiveEngine ABC, SimpleUpdateEngine, 5 engines
|       |-- scenarios.py                  # Scenario, ScenarioGenerator, hand-crafted fixtures
|       |-- metrics.py                    # DRI, AlphaFairness, distributional, procedural
|       |-- moderator.py                  # Moderator, GroupBuildingLevel, GroupAssigner
|       |-- protocols.py                  # Protocol ABC + 5 concrete formats
|       |-- experiment.py                 # ExperimentConfig, FactorialDesign, Runner
|       |-- history.py                    # StateSnapshot, SimulationHistory
|       `-- io.py                         # JSON/CSV output, structured logging
|-- experiments/
|   |-- degroot_baseline.py
|   |-- bayesian_calibration.py
|   |-- protocol_comparison.py
|   `-- factorial_sweep.py
|-- tests/
|   |-- conftest.py
|   |-- test_agents.py
|   |-- test_considerations.py
|   |-- test_engines.py
|   |-- test_scenarios.py
|   |-- test_metrics.py
|   |-- test_moderator.py
|   |-- test_protocols.py
|   `-- test_benchmarks.py
|-- pyproject.toml
`-- Makefile
```

### Core Design: The Consideration Bridge

The central architectural choice is representing agent cognition as a **consideration vector** rather than a scalar opinion. Each agent holds a dict mapping consideration IDs to weights in [-1, 1]. The agent's scalar opinion is a derived quantity:

```
opinion = sum(weight[c] * direction[c] for c in repertoire) / len(repertoire)
```

where `direction[c]` is the consideration's pro/con valence (from the `ArgumentPool`). The derivation function is a swappable `Callable` parameter on `Agent`, defaulting to this sum-of-products formula. This is semantically correct: a high weight on a pro consideration raises opinion; a high weight on a con consideration lowers it.

This design choice bridges the two traditions:
- **DeGroot limit**: Set all agents to a single consideration with direction=+1. The consideration weight IS the opinion. Update rules reduce to scalar averaging. DRI is undefined (degenerate).
- **Deliberation regime**: Give agents 10-30 considerations with heterogeneous weights. Different agents weight the same considerations differently. DRI measures whether pairwise similarity in consideration weights predicts pairwise similarity in derived preferences. Argumentation-based updating modifies consideration weights through attack/support evaluation.

DRI is then: for each pair (i,j), compute (a) cosine similarity of their consideration weight vectors, and (b) absolute difference in their derived opinions. DRI = Pearson correlation of (a) and (b) across all pairs. A positive DRI means agents who agree on reasons also agree on conclusions -- Niemeyer's "intersubjective consistency."

**Alternative rejected**: Treating considerations as a separate module decoupled from opinion. This would make DRI a post-hoc statistic rather than an emergent property. The whole point is that opinion *derives from* considerations, so when considerations change through argumentation, opinion changes as a consequence, and DRI tracks whether this derivation is consistent across agents.

### Key Design Decisions

**1. Frozen dataclasses for parameters, mutable classes for state.**
Follow the Olympus pattern (`CarbonParams`, `ClimateParams` are frozen; `TwoBoxClimate` is mutable). Agent parameters (prior_precision, open_mindedness, elaboration_quality, repertoire_size) are set at initialization and do not change. Agent state (consideration weights, opinion, history) evolves during simulation.

**2. Three-hook CognitiveEngine with SimpleUpdateEngine convenience base.**
A `CognitiveEngine` ABC with three methods -- `voice()`, `evaluate()`, `reflect()` -- that decompose agent cognition into the three theoretical functions identified in the literature: discourse (Lustick & Miodownik's argument voicing), persuasion (Butler et al.'s argument evaluation under grounded semantics), and reflection (Barabas's Bayesian posterior updating). A `SimpleUpdateEngine` base class collapses all three hooks into a single `update()` for rules that don't need the decomposition (DeGroot, Bayesian, BoundedConfidence). `ArgumentBasedEngine` implements all three hooks. `MixedEngine` composes at the hook level, enabling Butler et al.'s mixed dynamics (dyadic evaluation + deliberative reflection). This design moves `voice_argument()` off the `Agent` class and onto the engine, correctly separating state (agent) from behavior (engine). When LLM agents are introduced, only the engine is replaced.

**3. PrincipalProfile as a frozen data seed for future survey initialization.**
Each agent carries an optional `PrincipalProfile` -- a frozen dataclass with `initial_considerations`, `demographics`, and `source`. In the rule-based model, `principal=None` for synthetically generated agents. When ANES survey data is integrated in a future sprint, `AgentPopulation.from_survey()` will populate this field, enabling provenance tracking and the principal-agent relationship where the LLM engine pursues the principal's interests. No `vote()` method is added in this sprint -- vote=opinion in the rule-based model. The vote/opinion distinction becomes meaningful only when LLM reflection can weigh evolved considerations against the principal's original profile.

**4. Protocol as the primary independent variable.**
A `Protocol` ABC with methods `assign_groups(population) -> list[Group]`, `run_round(groups, round_num) -> RoundResult`, and `is_complete(round_num, population) -> bool`. Each concrete protocol (Plenary, Jury, CitizensAssembly, TownHall, CommitteePlenary) implements its own group formation, turn-taking, and termination logic. Protocols receive engines and moderators via constructor injection, not inheritance.

**5. ArgumentPool as shared environment with hand-crafted and generated scenarios.**
The argument pool is a property of the simulation, not of individual agents. Two sources: (a) hand-crafted scenarios for benchmark validation (Barabas "earnings cap" consensual, Barabas non-consensual), and (b) a `ScenarioGenerator` class with configurable `n_considerations`, `pro_con_balance`, `attack_density`, and `strength_distribution` for factorial sweeps. Both produce the same `Scenario` dataclass.

**6. Static repertoires by default, optional dynamic mode.**
Following Butler et al. (2019, ranked #2 in literature alignment), agents keep their initial repertoire throughout deliberation by default. An optional `repertoire_dynamics="learning"` parameter enables the Lustick & Miodownik mechanism where agents add voiced considerations to their repertoire. The `Agent` stores repertoire as `dict[str, float]` (not a frozen set) so dynamic mode requires no data structure change.

**7. No pandas, no hydra, no heavy frameworks.**
Dependencies: numpy (linear algebra), scipy (stats.pearsonr for DRI). Dev: pytest, mypy, ruff. The model is self-contained. Experiment configs are Python dataclasses, not YAML files. This keeps the cognitive load low and the toy model inspectable.

**8. History as append-only log.**
Each agent maintains a timestamped list of `StateSnapshot` objects (consideration weights, opinion, round number). `SimulationHistory` aggregates agent histories and metric time series. Output is JSON (one file per experiment run) and CSV (one row per agent per round, for analysis in R/pandas outside the model).

---

## 3. Sprint Backlog

### Story Map

```
US-001 (foundations) --> US-002 (engines) -------> US-005 (protocols)
                    |                            /
                    +--> US-003 (metrics)        /
                    |                           /
                    +--> US-004 (facilitation) -+
                                                \
                                                 +--> US-006 (experiments) --> US-007 (benchmarks)
```

### User Stories

---

#### US-001: Agent, Consideration, ArgumentPool, and PrincipalProfile core classes

**Why this story exists:** Every subsequent story depends on the agent's internal representation. The consideration-vector architecture is the foundational design that makes DRI computable and bridges DeGroot with Habermasian deliberation. The PrincipalProfile plants the data-structure seed for future ANES survey integration.

**What to change:**
- `src/agora/__init__.py`: Create. Export public API.
- `src/agora/agents.py`: Create. ~180 lines.
- `src/agora/considerations.py`: Create. ~200 lines.
- `src/agora/history.py`: Create. ~80 lines.
- `tests/conftest.py`: Create. Shared fixtures.
- `tests/test_agents.py`: Create.
- `tests/test_considerations.py`: Create.
- `pyproject.toml`: Create. Follow Olympus pattern.
- `Makefile`: Create. Targets: install, test, lint, type.

**How to implement:**

`considerations.py`:
```python
@dataclass(frozen=True)
class Consideration:
    id: str                    # e.g. "earnings_cap_fair"
    label: str                 # human-readable: "Raising the earnings cap is fair"
    direction: float           # -1.0 to 1.0 (pro/con on the issue)
    base_strength: float       # 0.0 to 1.0 (argument quality, used by engines during evaluation)

@dataclass
class AttackGraph:
    """Directed graph of attack/support relations between considerations."""
    attacks: dict[tuple[str, str], float]   # (attacker_id, target_id) -> strength in (0,1]
    supports: dict[tuple[str, str], float]  # (supporter_id, target_id) -> strength in (0,1]

    def get_attackers(self, target_id: str) -> list[tuple[str, float]]: ...
    def get_supporters(self, target_id: str) -> list[tuple[str, float]]: ...

class ArgumentPool:
    """Shared environment of all possible considerations and their relations."""
    def __init__(self, considerations: list[Consideration], attack_graph: AttackGraph): ...

    def get(self, cid: str) -> Consideration: ...
    def sample_repertoire(self, size: int, rng: np.random.Generator) -> list[str]: ...
    def get_direction_vector(self, cids: list[str]) -> np.ndarray: ...
```

`agents.py`:
```python
@dataclass(frozen=True)
class PrincipalProfile:
    """Immutable record of the survey respondent this agent represents.
    None for synthetically-generated agents (rule-based sprint).
    Populated from ANES/survey data in future sprints."""
    initial_considerations: dict[str, float]  # original agree/disagree vector
    demographics: dict[str, Any]              # age, income, education, partisanship
    source: str                               # "random" | "anes_2024" | etc.

@dataclass(frozen=True)
class AgentParams:
    prior_precision: float       # [0.1, 10.0] -- Barabas: how firmly held
    open_mindedness: float       # [0.0, 1.0] -- Niemeyer: willingness to revise
    elaboration_quality: float   # [0.0, 1.0] -- Leeper & Slothuus: central vs peripheral
    latitude_acceptance: float   # [0.0, 2.0] -- Butler: assimilation threshold
    latitude_rejection: float    # [0.0, 2.0] -- Butler: contrast threshold
    repertoire_size: int         # [3, 30] -- Lustick: how many args agent can hold

# Default opinion derivation: sum(weight * direction) / len(repertoire)
OpinionFn = Callable[[dict[str, float], ArgumentPool], float]

def default_opinion_fn(weights: dict[str, float], pool: ArgumentPool) -> float:
    """Sum of (weight * consideration direction) / repertoire size."""
    if not weights:
        return 0.0
    return sum(w * pool.get(cid).direction for cid, w in weights.items()) / len(weights)

class Agent:
    def __init__(self, id: int, params: AgentParams, repertoire: list[str],
                 initial_weights: dict[str, float], pool: ArgumentPool,
                 opinion_fn: OpinionFn = default_opinion_fn,
                 principal: PrincipalProfile | None = None): ...

    @property
    def opinion(self) -> float:
        """Derived from consideration weights via opinion_fn."""
        return self._opinion_fn(self._weights, self._pool)

    @property
    def consideration_vector(self) -> np.ndarray:
        """Ordered weight vector for pairwise comparison."""

    @property
    def principal(self) -> PrincipalProfile | None:
        """Read-only access to the principal profile."""

    def add_to_repertoire(self, cid: str, initial_weight: float = 0.0) -> None:
        """Lustick mechanism: agent learns about a new consideration."""

    def update_weight(self, cid: str, new_weight: float) -> None:
        """Set consideration weight. Called by engines, not by external code."""

    def snapshot(self, round_num: int) -> StateSnapshot: ...

class AgentPopulation:
    def __init__(self, agents: list[Agent], pool: ArgumentPool): ...

    @classmethod
    def generate(cls, n: int, pool: ArgumentPool, rng: np.random.Generator,
                 param_distributions: dict | None = None) -> AgentPopulation:
        """Factory. Draws agent params from distributions, assigns repertoires.
        Sets principal=None (synthetic agents)."""

    def opinions(self) -> np.ndarray: ...
    def get_agent(self, id: int) -> Agent: ...
    def subpopulation(self, ids: list[int]) -> AgentPopulation: ...
```

`history.py`:
```python
@dataclass(frozen=True)
class StateSnapshot:
    round_num: int
    weights: dict[str, float]   # consideration_id -> weight
    opinion: float
    repertoire: frozenset[str]

class SimulationHistory:
    """Append-only log of all state changes and metric computations."""
    def __init__(self): ...
    def record_agent_state(self, agent_id: int, snapshot: StateSnapshot) -> None: ...
    def record_metrics(self, round_num: int, metrics: dict[str, float]) -> None: ...
    def to_json(self) -> dict: ...
    def agent_opinion_series(self, agent_id: int) -> list[float]: ...
    def metric_series(self, metric_name: str) -> list[float]: ...
```

**Acceptance criteria:**
- [ ] `Agent.opinion` is a derived property computed via `opinion_fn(weights, pool)`, not stored independently
- [ ] Default `opinion_fn` computes `sum(weight * direction) / len(repertoire)` and returns values in [-1, 1]
- [ ] Custom `opinion_fn` can be injected at construction (tested with a lambda)
- [ ] `PrincipalProfile` is a frozen dataclass; `Agent.principal` is a read-only property returning `None` for synthetic agents
- [ ] `AgentPopulation.generate()` produces heterogeneous agents with varying params and repertoires, `principal=None`
- [ ] `ArgumentPool.sample_repertoire()` returns subsets of the full consideration set
- [ ] `AttackGraph` correctly reports attackers and supporters for any consideration
- [ ] `Agent.add_to_repertoire()` adds a new consideration without disrupting existing weights
- [ ] All classes are fully type-hinted; `mypy src/agora` passes
- [ ] `pytest tests/test_agents.py tests/test_considerations.py` passes
- [ ] Test coverage: agent creation, opinion derivation (default + custom), principal profile, population generation, repertoire sampling, attack graph queries, snapshot/history recording

**Depends on:** none
**Estimated complexity:** L

---

#### US-002: Cognitive engines -- voice, evaluate, reflect

**Why this story exists:** The cognitive engine is what makes deliberation happen. The three-hook decomposition (voice/evaluate/reflect) maps to real theoretical constructs: discourse (Lustick & Miodownik's argument voicing), persuasion (Butler et al.'s argument evaluation under grounded semantics), and reflection (Barabas's Bayesian posterior updating). Separating these functions enables fine-grained composability (Butler's mixed dynamics: dyadic evaluation + deliberative reflection) and creates the clean swap point for LLM agents. The `SimpleUpdateEngine` base class ensures simple rules (DeGroot, Bayesian, BC) remain one-method implementations.

**What to change:**
- `src/agora/engines.py`: Create. ~300 lines.
- `tests/test_engines.py`: Create.

**How to implement:**

```python
class CognitiveEngine(ABC):
    """Three-hook interface for agent cognition.
    voice: select which consideration to articulate (discourse)
    evaluate: assess incoming argument's influence (persuasion)
    reflect: revise consideration weights after round (reflection)
    """
    @abstractmethod
    def voice(self, agent: Agent, pool: ArgumentPool,
              rng: np.random.Generator) -> tuple[str, float]:
        """Select a consideration to voice and its framing weight.
        Returns (consideration_id, framing_weight)."""

    @abstractmethod
    def evaluate(self, agent: Agent, consideration_id: str,
                 speaker_opinion: float, pool: ArgumentPool,
                 rng: np.random.Generator) -> float:
        """Assess influence weight of an incoming argument.
        Returns influence weight in [0, 1]."""

    @abstractmethod
    def reflect(self, agent: Agent, round_updates: list[tuple[str, float, float]],
                pool: ArgumentPool, rng: np.random.Generator) -> None:
        """Revise agent's consideration weights after hearing all arguments.
        round_updates is [(consideration_id, influence_weight, speaker_opinion), ...].
        Modifies agent state in place."""


class SimpleUpdateEngine(CognitiveEngine):
    """Convenience base for rules where evaluate+reflect collapse into one step.
    Subclasses implement only update(). Gets voice/evaluate/reflect defaults."""

    def voice(self, agent: Agent, pool: ArgumentPool,
              rng: np.random.Generator) -> tuple[str, float]:
        """Default: select from repertoire with probability proportional to |weight|."""
        weights = {cid: abs(agent._weights[cid]) for cid in agent._weights}
        total = sum(weights.values())
        if total == 0:
            cid = rng.choice(list(agent._weights.keys()))
        else:
            probs = np.array([weights[cid] / total for cid in agent._weights])
            cid = rng.choice(list(agent._weights.keys()), p=probs)
        return cid, agent._weights[cid]

    def evaluate(self, agent: Agent, consideration_id: str,
                 speaker_opinion: float, pool: ArgumentPool,
                 rng: np.random.Generator) -> float:
        """Accept all; let update() handle filtering."""
        return 1.0

    def reflect(self, agent: Agent, round_updates: list[tuple[str, float, float]],
                pool: ArgumentPool, rng: np.random.Generator) -> None:
        """Delegates to update() for each incoming argument."""
        for cid, influence, speaker_opinion in round_updates:
            self.update(agent, cid, influence, speaker_opinion, pool, rng)

    @abstractmethod
    def update(self, agent: Agent, consideration_id: str, influence: float,
               speaker_opinion: float, pool: ArgumentPool,
               rng: np.random.Generator) -> None:
        """Single-step update per argument. Subclasses implement only this."""


class DeGrootEngine(SimpleUpdateEngine):
    """Scalar weighted averaging. o_i(t+1) = o_i(t) + mu * (o_j(t) - o_i(t)).
    Operates on derived opinion scalar (bypasses consideration layer).
    Degenerate baseline case."""
    def __init__(self, mu: float = 0.3):
        self.mu = mu

    def update(self, agent, consideration_id, influence, speaker_opinion, pool, rng):
        # Scale all consideration weights uniformly to shift derived opinion toward speaker
        delta = self.mu * (speaker_opinion - agent.opinion)
        for cid in agent._weights:
            agent.update_weight(cid, agent._weights[cid] + delta / len(agent._weights))


class BayesianEngine(SimpleUpdateEngine):
    """Barabas (2004) precision-weighted updating.
    posterior = (prior_prec * prior + signal_prec * signal) / (prior_prec + signal_prec).
    Operates on consideration weights: each voiced argument shifts the weight of the
    corresponding consideration proportional to signal strength / prior precision."""
    def __init__(self, signal_precision_base: float = 1.0):
        self.signal_precision_base = signal_precision_base

    def update(self, agent, consideration_id, influence, speaker_opinion, pool, rng):
        if consideration_id not in agent._weights:
            return
        prior = agent._weights[consideration_id]
        signal = pool.get(consideration_id).direction * influence
        signal_prec = self.signal_precision_base * pool.get(consideration_id).base_strength
        prior_prec = agent.params.prior_precision
        posterior = (prior_prec * prior + signal_prec * signal) / (prior_prec + signal_prec)
        agent.update_weight(consideration_id, posterior)


class BoundedConfidenceEngine(SimpleUpdateEngine):
    """Butler et al. Eq. 5. Assimilate if |o_i - o_j| < U_i, contrast if > T_i.
    o_i(t+1) = o_i(t) + mu * (o_j(t) - o_i(t))  [assimilation]
    o_i(t+1) = o_i(t) - mu * (o_j(t) - o_i(t))  [contrast]
    Uses agent.params.latitude_acceptance and latitude_rejection.
    Operates on the derived opinion scalar."""
    def __init__(self, mu: float = 0.3):
        self.mu = mu

    def update(self, agent, consideration_id, influence, speaker_opinion, pool, rng):
        dist = abs(agent.opinion - speaker_opinion)
        if dist < agent.params.latitude_acceptance:
            # Assimilation: shift toward speaker
            delta = self.mu * (speaker_opinion - agent.opinion)
            for cid in agent._weights:
                agent.update_weight(cid, agent._weights[cid] + delta / len(agent._weights))
        elif dist > agent.params.latitude_rejection:
            # Contrast: shift away from speaker
            delta = self.mu * (speaker_opinion - agent.opinion)
            for cid in agent._weights:
                agent.update_weight(cid, agent._weights[cid] - delta / len(agent._weights))
        # Intermediate zone: no change


class ArgumentBasedEngine(CognitiveEngine):
    """Butler et al. Eq. 6. Uses all three hooks meaningfully.
    voice: strategic -- focused agents defend proposals, naive voice nearest to opinion.
    evaluate: grounded semantics -- check attack/support relations, compute acceptance probability.
    reflect: revise consideration weights based on all evaluated arguments in the round."""
    def __init__(self, p_accept: float = 0.7, p_reject: float = 0.3,
                 strategic_voicing: bool = False):
        self.p_accept = p_accept
        self.p_reject = p_reject
        self.strategic_voicing = strategic_voicing

    def voice(self, agent, pool, rng):
        if self.strategic_voicing:
            # Focused: voice the consideration with highest |weight * direction|
            best = max(agent._weights, key=lambda c: abs(agent._weights[c] * pool.get(c).direction))
            return best, agent._weights[best]
        else:
            # Naive: probability proportional to |weight| (same as SimpleUpdateEngine default)
            weights = {c: abs(w) for c, w in agent._weights.items()}
            total = sum(weights.values())
            if total == 0:
                cid = rng.choice(list(agent._weights.keys()))
            else:
                probs = np.array([weights[c] / total for c in agent._weights])
                cid = rng.choice(list(agent._weights.keys()), p=probs)
            return cid, agent._weights[cid]

    def evaluate(self, agent, consideration_id, speaker_opinion, pool, rng):
        """Grounded semantics: argument is 'in' if no undefeated attacker exists
        in the agent's repertoire. Returns influence weight."""
        attackers = pool.attack_graph.get_attackers(consideration_id)
        for attacker_id, attack_strength in attackers:
            if attacker_id in agent._weights:
                # Check if attacker is itself defeated
                attacker_attackers = pool.attack_graph.get_attackers(attacker_id)
                attacker_defeated = any(
                    aa_id in agent._weights and abs(agent._weights[aa_id]) > 0.5
                    for aa_id, _ in attacker_attackers
                )
                if not attacker_defeated:
                    return attack_strength * 0.1  # Greatly reduced influence
        return 1.0  # Argument is "in" -- full influence

    def reflect(self, agent, round_updates, pool, rng):
        """Revise weights. For each 'in' argument:
        If agent agrees (same sign): shift toward with prob x_i = p_a^|delta_i|
        If agent disagrees: shift away with prob y_i = p_r^(1/|delta_i|)"""
        for cid, influence, speaker_opinion in round_updates:
            if cid not in agent._weights:
                continue
            if influence < 0.5:
                continue  # Argument was defeated
            direction = pool.get(cid).direction
            current = agent._weights[cid]
            delta = abs(direction - current) / 2.0
            if delta < 0.01:
                continue
            if current * direction >= 0:  # Same sign: agent agrees
                prob = self.p_accept ** delta
                if rng.random() < prob:
                    agent.update_weight(cid, current + 0.1 * (direction - current))
            else:  # Opposite sign: agent disagrees
                prob = self.p_reject ** (1.0 / delta)
                if rng.random() < prob:
                    agent.update_weight(cid, current - 0.1 * (direction - current))


class MixedEngine(CognitiveEngine):
    """Compose engines at the hook level. Enables Butler et al.'s mixed dynamics:
    e.g., BoundedConfidence evaluation with ArgumentBased reflection.
    Can also select among full engines with specified probabilities."""
    def __init__(self, engines: list[tuple[CognitiveEngine, float]]):
        """engines is [(engine, probability), ...], probabilities must sum to 1."""
        self.engines = engines
        total = sum(p for _, p in engines)
        assert abs(total - 1.0) < 1e-6, f"Probabilities must sum to 1, got {total}"

    def _select(self, rng: np.random.Generator) -> CognitiveEngine:
        probs = [p for _, p in self.engines]
        idx = rng.choice(len(self.engines), p=probs)
        return self.engines[idx][0]

    def voice(self, agent, pool, rng):
        return self._select(rng).voice(agent, pool, rng)

    def evaluate(self, agent, consideration_id, speaker_opinion, pool, rng):
        return self._select(rng).evaluate(agent, consideration_id, speaker_opinion, pool, rng)

    def reflect(self, agent, round_updates, pool, rng):
        self._select(rng).reflect(agent, round_updates, pool, rng)
```

Key implementation detail for `ArgumentBasedEngine.evaluate()`: "grounded semantics" evaluation. An argument is "in" if no undefeated argument attacks it. Check the `AttackGraph`: for each attacker of the voiced argument, check if the attacker itself is attacked by something in the agent's repertoire with sufficient weight. This is a simplified version of Dung's grounded semantics -- full computation is NP-hard, but with small repertoires (3-30) it is tractable via direct inspection.

**Acceptance criteria:**
- [ ] `DeGrootEngine` produces weighted average convergence: after many rounds with complete mixing, all agents converge to the population mean
- [ ] `BayesianEngine` produces larger updates for agents with low `prior_precision` and smaller updates for high `prior_precision` (Barabas mechanism)
- [ ] `BoundedConfidenceEngine` produces assimilation when opinion distance < `latitude_acceptance`, contrast when > `latitude_rejection`, no change in the intermediate zone
- [ ] `ArgumentBasedEngine.voice()` with `strategic_voicing=True` selects the highest-impact consideration
- [ ] `ArgumentBasedEngine.evaluate()` returns reduced influence for arguments attacked by undefeated considerations in agent's repertoire
- [ ] `ArgumentBasedEngine.reflect()` modifies consideration weights, not opinions directly; opinion changes as a consequence
- [ ] `MixedEngine` selects among constituent engines with correct probabilities (verified over 10,000 samples)
- [ ] All engines implement the `CognitiveEngine` interface and are interchangeable
- [ ] `SimpleUpdateEngine` subclasses need only implement `update()` -- voice/evaluate/reflect work via defaults
- [ ] `pytest tests/test_engines.py` passes

**Depends on:** US-001
**Estimated complexity:** L

---

#### US-003: Metrics -- DRI, alpha-fairness, distributional, procedural

**Why this story exists:** Without DRI, the model cannot be validated against Niemeyer et al. (2024). Without distributional metrics, it cannot be compared to Butler et al. (2019). The alpha-fairness family from Bertsimas et al. (2012) provides a single-parameter sweep of the utilitarian-to-Rawlsian spectrum. These metrics are the dependent variables of every experiment.

**What to change:**
- `src/agora/metrics.py`: Create. ~250 lines.
- `tests/test_metrics.py`: Create.

**How to implement:**

```python
class DRI:
    """Deliberative Reason Index (Niemeyer et al. 2024).
    Intersubjective consistency: correlation between pairwise consideration-agreement
    and pairwise preference-agreement across all agent pairs.
    """
    @staticmethod
    def compute(population: AgentPopulation) -> float:
        # For each pair (i, j) with shared repertoire overlap:
        #   consideration_sim = cosine_similarity(shared weight vectors)
        #   preference_sim = 1.0 - abs(agent_i.opinion - agent_j.opinion)
        # Return pearsonr(consideration_sims, preference_sims)[0]
        # Working range: [-1, 1], typical deliberation effect: +0.113

    @staticmethod
    def compute_delta(pop_before: AgentPopulation, pop_after: AgentPopulation) -> float:
        """DRI change from pre to post deliberation. Target: +0.113 (Niemeyer)."""

class AlphaFairness:
    """Bertsimas, Farias & Trichakis (2012). Alpha-fairness welfare function."""
    @staticmethod
    def compute(utilities: np.ndarray, alpha: float) -> float:
        # alpha=0: utilitarian (sum), alpha=1: proportional (Nash product),
        # alpha->inf: Rawlsian (max-min)
        # W_alpha = sum(u_j^(1-alpha) / (1-alpha)) for alpha != 1
        # W_1 = sum(log(u_j))

    @staticmethod
    def price_of_fairness(utilities: np.ndarray, alpha: float) -> float:
        """POF = 1 - W_alpha / W_0 (utilitarian welfare lost for fairness)."""

    @staticmethod
    def price_of_efficiency(utilities: np.ndarray, alpha: float) -> float:
        """POE = 1 - min(u) / min(u*) where u* is the alpha-fair optimum."""

class DistributionalMetrics:
    """Butler et al. (2019) outcome measures."""
    @staticmethod
    def opinion_variance(population: AgentPopulation) -> float: ...

    @staticmethod
    def extremist_proportion(population: AgentPopulation, threshold: float = 0.75) -> float:
        """Proportion of agents with |opinion| >= threshold. Butler: |o_i| >= 0.75."""

    @staticmethod
    def opinion_shifts(pop_before: AgentPopulation, pop_after: AgentPopulation) -> float:
        """Butler Sh = 2 * sum(|o_0 - o_final|) / (max - min). Normalized total movement."""

    @staticmethod
    def herfindahl(population: AgentPopulation, n_bins: int = 10) -> float:
        """Lustick & Miodownik: concentration index of opinion distribution."""

    @staticmethod
    def agreement_clustering(population: AgentPopulation) -> float:
        """Lustick: 1 - diversity. How concentrated is opinion around modes."""

class ProceduralMetrics:
    """Content-based measures enabled by the consideration architecture."""
    @staticmethod
    def argument_diversity(history: SimulationHistory, round_num: int) -> float:
        """Unique considerations voiced in a round / total considerations in pool."""

    @staticmethod
    def responsiveness(history: SimulationHistory, round_num: int) -> float:
        """Proportion of agents whose consideration weights changed in response to voiced args."""

    @staticmethod
    def speaking_equity(history: SimulationHistory, round_num: int) -> float:
        """1 - Gini coefficient of speaking turns across agents."""

class MetricsSuite:
    """Convenience: compute all metrics at once."""
    def __init__(self, alpha_values: list[float] = [0, 1, 2]): ...
    def compute_all(self, population: AgentPopulation,
                    history: SimulationHistory | None = None,
                    round_num: int = 0) -> dict[str, float]: ...
```

DRI implementation detail: cosine similarity for consideration vectors requires that both agents' vectors be projected onto their shared consideration space (the intersection of their repertoires). If agents have zero overlap, that pair is excluded from the correlation. This is a design choice -- shared-repertoire-only is more faithful to the Niemeyer construct (you can only have intersubjective consistency about things both parties have considered).

**Acceptance criteria:**
- [ ] `DRI.compute()` returns 1.0 when all agents have identical consideration weight vectors (perfect intersubjective consistency)
- [ ] `DRI.compute()` returns approximately 0.0 when consideration weights and preferences are uncorrelated (random initialization with sufficient agents)
- [ ] `AlphaFairness.compute()` at alpha=0 returns the sum of utilities
- [ ] `AlphaFairness.compute()` at alpha=1 returns the sum of log utilities (proportional fairness)
- [ ] `DistributionalMetrics.opinion_variance()` matches numpy.var on the same data
- [ ] `DistributionalMetrics.extremist_proportion()` correctly counts agents outside threshold
- [ ] `ProceduralMetrics.speaking_equity()` returns 1.0 when all agents speak equally and <1.0 otherwise
- [ ] `MetricsSuite.compute_all()` returns a dict with all metric names as keys
- [ ] `pytest tests/test_metrics.py` passes

**Depends on:** US-001
**Estimated complexity:** M

---

#### US-004: Facilitation and group building

**Why this story exists:** Group building is the dominant institutional predictor of deliberative quality (Niemeyer: 0.076 per level, R^2=0.166). Facilitation reverses the modal outcome from polarization to depolarization (Caluwaerts: 52.2% vs 56%). These are not optional features -- they are the most consequential experimental parameters. Implemented before protocols because protocols inject moderators.

**What to change:**
- `src/agora/moderator.py`: Create. ~200 lines.
- `tests/test_moderator.py`: Create.

**How to implement:**

```python
class GroupBuildingLevel(IntEnum):
    """Niemeyer et al. (2024) 5-level ordinal scale."""
    MINIMAL = 1            # No preparation
    ICEBREAKER = 2         # Social introductions
    NORM_SETTING = 3       # Establish ground rules
    COGNITIVE_TRAINING = 4 # Teach deliberative skills
    FULL = 5               # Training + participatory norm generation

    def open_mindedness_bonus(self) -> float:
        """Higher group building reduces prior precision (increases open-mindedness).
        Coefficient: 0.076 per level (Niemeyer). Maps to multiplier on agent.params.open_mindedness."""
        return (self.value - 1) * 0.076

class GroupAssigner:
    """Assign agents to deliberation groups."""
    @staticmethod
    def heterogeneous(population: AgentPopulation, group_size: int,
                      rng: np.random.Generator) -> list[list[int]]:
        """Maximize opinion diversity within groups. Sort by opinion, deal round-robin."""

    @staticmethod
    def homogeneous(population: AgentPopulation, group_size: int,
                    rng: np.random.Generator) -> list[list[int]]:
        """Minimize opinion diversity within groups. Sort by opinion, cut contiguous blocks."""

    @staticmethod
    def random(population: AgentPopulation, group_size: int,
               rng: np.random.Generator) -> list[list[int]]:
        """Uniform random assignment."""

class Moderator:
    """Facilitation agent implementing Epstein & Leshed (2016) triage hierarchy.
    Priority order: (1) civility violations, (2) newcomer inclusion, (3) substantive intervention.
    In the rule-based model, the moderator is not an agent with opinions but a procedural function
    that modifies the deliberation process.
    """
    def __init__(self, active: bool = True, triage_weights: tuple[float,float,float] = (0.5, 0.3, 0.2)):
        self.active = active
        self.triage_weights = triage_weights  # civility, newcomer, substantive

    def enforce_speaking_equity(self, group: list[Agent], speaking_counts: dict[int, int],
                                rng: np.random.Generator) -> list[int]:
        """Reorder speaking queue to prioritize agents who have spoken least.
        Newcomer inclusion: agents with 0 speaking turns get priority."""

    def intervene_substantive(self, group: list[Agent], pool: ArgumentPool,
                              rng: np.random.Generator) -> list[str]:
        """Introduce underrepresented considerations.
        Select considerations from pool that no agent in the group has voiced.
        Returns list of consideration IDs to inject into the round."""

    def adjust_open_mindedness(self, agent: Agent, group_building: GroupBuildingLevel) -> float:
        """Apply group building bonus to agent's effective open-mindedness for this round.
        Does not modify agent.params (frozen); returns adjusted value for use by engines."""
```

**Acceptance criteria:**
- [ ] `GroupAssigner.heterogeneous()` produces groups with higher within-group opinion variance than `GroupAssigner.homogeneous()`
- [ ] `GroupAssigner.homogeneous()` produces groups with lower within-group opinion variance than random assignment
- [ ] `GroupBuildingLevel.open_mindedness_bonus()` returns 0.0 at level 1 and 0.304 at level 5
- [ ] `Moderator.enforce_speaking_equity()` places agents with 0 speaking turns before agents with >0 turns
- [ ] `Moderator.intervene_substantive()` returns only considerations not already in any group member's repertoire
- [ ] When `Moderator.active == False`, all intervention methods are no-ops (return unmodified inputs)
- [ ] `pytest tests/test_moderator.py` passes

**Depends on:** US-001
**Estimated complexity:** M

---

#### US-005: Deliberation protocols for classic mini-public formats

**Why this story exists:** The protocol is the primary independent variable. Different institutional formats produce different deliberative outcomes (Caluwaerts: 54.8% depolarize in heterogeneous facilitated vs 63.6% polarize in homogeneous unfacilitated). The protocol encodes who speaks when, in what groups, under what rules. Without protocols, there is no institutional experiment.

**What to change:**
- `src/agora/protocols.py`: Create. ~350 lines.
- `tests/test_protocols.py`: Create.

**How to implement:**

```python
@dataclass(frozen=True)
class RoundResult:
    round_num: int
    groups: list[list[int]]           # agent IDs per group
    voiced_arguments: dict[int, list[str]]  # agent_id -> considerations voiced
    opinion_changes: dict[int, float]       # agent_id -> delta opinion
    moderator_interventions: int

class Protocol(ABC):
    """Base class for deliberation formats."""
    def __init__(self, engine: CognitiveEngine, moderator: Moderator | None = None,
                 group_building: GroupBuildingLevel = GroupBuildingLevel.MINIMAL,
                 n_rounds: int = 5,
                 repertoire_dynamics: str = "static"): ...
                 # repertoire_dynamics: "static" (Butler) | "learning" (Lustick)

    @abstractmethod
    def assign_groups(self, population: AgentPopulation,
                      rng: np.random.Generator) -> list[list[int]]: ...

    @abstractmethod
    def run_round(self, population: AgentPopulation, round_num: int,
                  pool: ArgumentPool, rng: np.random.Generator,
                  history: SimulationHistory) -> RoundResult: ...

    def is_complete(self, round_num: int, population: AgentPopulation) -> bool:
        return round_num >= self.n_rounds

    def run(self, population: AgentPopulation, pool: ArgumentPool,
            rng: np.random.Generator) -> SimulationHistory:
        """Execute full deliberation. Returns history."""
```

The protocol loop in `run_round()` calls the three engine hooks:

```python
# Within run_round():
for group_ids in groups:
    group_agents = [population.get_agent(id) for id in group_ids]
    speaking_order = self._get_speaking_order(group_agents, round_num)
    
    # Accumulate pending updates for batch reflection
    pending: dict[int, list[tuple[str, float, float]]] = {a.id: [] for a in group_agents}
    
    for speaker in speaking_order:
        # 1. VOICE: engine selects what to say
        cid, framing = self.engine.voice(speaker, pool, rng)
        
        # 2. EVALUATE: each listener assesses the argument
        for listener in group_agents:
            if listener.id == speaker.id:
                continue
            influence = self.engine.evaluate(listener, cid, speaker.opinion, pool, rng)
            pending[listener.id].append((cid, influence, speaker.opinion))
            
            # Optional: dynamic repertoire (Lustick mechanism)
            if self.repertoire_dynamics == "learning" and cid not in listener._weights:
                listener.add_to_repertoire(cid, initial_weight=0.0)
    
    # 3. REFLECT: batch revision after all speakers
    for agent in group_agents:
        self.engine.reflect(agent, pending[agent.id], pool, rng)
```

Concrete protocol implementations:

```python
class Plenary(Protocol):
    """All agents in one group. Round-robin speaking order.
    Every agent voices one argument per round. All others hear it and update.
    Simple but scales poorly (K&B: consensus prob -> 0 at n>13)."""

class Jury(Protocol):
    """Fixed group of 12. Moderated. Sequential deliberation.
    Calibration target: ~90% of verdicts match pre-deliberation majority (Kalven & Zeisel via Gastil)."""
    def __init__(self, ..., jury_size: int = 12): ...

class CitizensAssembly(Protocol):
    """Three-phase format modeled on Barabas (2004) ADSS design.
    Phase 1 (information): All agents receive full argument pool (repertoire expansion).
    Phase 2 (small group): Breakout groups of 8-12 deliberate for k rounds.
    Phase 3 (plenary): Groups report back, full-population round.
    Group composition determined by GroupAssigner (heterogeneous/homogeneous/random)."""
    def __init__(self, ..., breakout_size: int = 10, breakout_rounds: int = 3,
                 plenary_rounds: int = 2, group_assigner: GroupAssigner = None): ...

class TownHall(Protocol):
    """Unstructured. Random speaking order. No facilitation. No subgroups.
    Baseline for non-deliberative comparison.
    Caluwaerts: 56% polarization in non-facilitated settings."""

class CommitteePlenary(Protocol):
    """K&B subgroup structure. Committee of n_committee deliberates for k rounds,
    then reports to plenary. Plenary votes.
    K&B: n* = 13 max net-positive committee size."""
    def __init__(self, ..., committee_size: int = 10, committee_rounds: int = 5,
                 plenary_rounds: int = 2, committee_composition: str = "heterogeneous"): ...
```

**Acceptance criteria:**
- [ ] `Plenary` puts all agents in one group; every agent speaks once per round
- [ ] `Jury` produces a group of exactly `jury_size` agents
- [ ] `CitizensAssembly` executes three distinct phases (information, breakout, plenary) with group reformation between phases
- [ ] `TownHall` has no moderator interventions even if a Moderator object is passed (override to inactive)
- [ ] `CommitteePlenary` runs committee rounds before plenary rounds; committee reports expand plenary agents' repertoires
- [ ] All protocols produce a `SimulationHistory` with per-round agent snapshots
- [ ] `Protocol.run()` is deterministic given the same seed
- [ ] Protocol loop calls `engine.voice()`, `engine.evaluate()`, `engine.reflect()` in correct order
- [ ] `repertoire_dynamics="learning"` causes agents to add voiced considerations they don't already hold
- [ ] After `Plenary.run()` with `DeGrootEngine`, opinions converge toward the mean (DeGroot theorem)
- [ ] `pytest tests/test_protocols.py` passes

**Depends on:** US-001, US-002, US-004
**Estimated complexity:** L

---

#### US-006: Experiment runner, scenarios, and factorial design

**Why this story exists:** The research goal is to map the coordination-and-agreement subspace as a function of institutional designs. This requires systematic sweeps over protocol type, group size, group composition, facilitation, group building level, engine type, and number of rounds. The experiment runner generates the full factorial cross, executes runs with seed management, and collects structured output. Hand-crafted scenarios provide benchmark validation; the generator provides parameterized scenarios for sweeps.

**What to change:**
- `src/agora/scenarios.py`: Create. ~150 lines.
- `src/agora/experiment.py`: Create. ~200 lines.
- `src/agora/io.py`: Create. ~100 lines.
- `tests/test_scenarios.py`: Create.
- `experiments/degroot_baseline.py`: Create.
- `experiments/bayesian_calibration.py`: Create.
- `experiments/protocol_comparison.py`: Create.
- `experiments/factorial_sweep.py`: Create.

**How to implement:**

`scenarios.py`:
```python
@dataclass
class Scenario:
    """A complete argument environment for one deliberation."""
    name: str
    pool: ArgumentPool
    description: str = ""

class ScenarioGenerator:
    """Programmatic scenario creation for factorial sweeps."""
    @staticmethod
    def generate(name: str, n_considerations: int = 15,
                 pro_con_balance: float = 0.5,
                 attack_density: float = 0.2,
                 strength_distribution: str = "uniform",
                 rng: np.random.Generator = None) -> Scenario:
        """Create a scenario with parameterized properties.
        pro_con_balance: fraction of pro-direction considerations (0.5 = balanced).
        attack_density: probability that any two considerations have an attack relation.
        strength_distribution: "uniform" | "beta" for base_strength values."""

# Hand-crafted validation scenarios
def barabas_consensual() -> Scenario:
    """Barabas (2004) earnings cap scenario. >5:1 pro-to-con ratio.
    15 considerations: 13 pro (direction > 0), 2 con (direction < 0).
    Moderate attack density among opposing considerations."""

def barabas_non_consensual() -> Scenario:
    """Barabas (2004) privatization scenario. Balanced pro/con.
    15 considerations: 7 pro, 8 con, with cross-cutting attack relations."""

def jackman_sniderman_symmetric() -> Scenario:
    """Jackman & Sniderman (2006) symmetric argument quality.
    15 considerations: balanced pro/con, equal base_strength on both sides.
    Dense cross-cutting attacks."""
```

`experiment.py`:
```python
@dataclass(frozen=True)
class ExperimentConfig:
    # Identifiers
    name: str
    seed: int

    # Population
    n_agents: int = 20
    n_considerations: int = 15
    repertoire_size_range: tuple[int, int] = (5, 12)

    # Institutional parameters (the IVs)
    protocol: str = "plenary"                    # plenary|jury|assembly|townhall|committee
    engine: str = "bayesian"                     # degroot|bayesian|bc|argument|mixed
    group_size: int = 10                         # for protocols with subgroups
    group_composition: str = "heterogeneous"     # heterogeneous|homogeneous|random
    facilitation: bool = True
    group_building_level: int = 3                # 1-5
    n_rounds: int = 5
    voting_rule: str = "majority"                # majority|supermajority|consensus
    repertoire_dynamics: str = "static"          # static|learning

    # Engine parameters
    mu: float = 0.3                              # DeGroot/BC learning rate
    signal_precision: float = 1.0                # Bayesian signal precision
    p_accept: float = 0.7                        # ArgumentBased acceptance probability
    p_reject: float = 0.3                        # ArgumentBased rejection probability

    # Scenario
    scenario: str = "generated"                  # generated|barabas_consensual|barabas_non_consensual|...
    pro_con_balance: float = 0.5                 # for generated scenarios

    # Alpha-fairness sweep
    alpha_values: tuple[float, ...] = (0.0, 1.0, 2.0)

class FactorialDesign:
    """Generate full cross of parameter levels."""
    def __init__(self, factors: dict[str, list]): ...

    def generate_configs(self, base_name: str, n_replications: int = 10,
                         base_seed: int = 42) -> list[ExperimentConfig]:
        """Full factorial cross with n_replications per cell. Seeds are deterministic."""

    @property
    def n_cells(self) -> int: ...

    @property
    def n_runs(self) -> int: ...

class Runner:
    """Execute experiment configs and collect results."""
    def __init__(self, output_dir: str = "results"): ...

    def run_single(self, config: ExperimentConfig) -> dict:
        """Execute one config. Returns metrics dict."""
        # 1. Build Scenario from config.scenario / ScenarioGenerator
        # 2. Build AgentPopulation with config.n_agents
        # 3. Instantiate CognitiveEngine from config.engine
        # 4. Instantiate Moderator from config.facilitation
        # 5. Instantiate Protocol from config.protocol
        # 6. Run protocol
        # 7. Compute MetricsSuite on final state
        # 8. Return {config params} + {metrics}

    def run_batch(self, configs: list[ExperimentConfig],
                  parallel: bool = False) -> list[dict]:
        """Execute all configs. Optionally parallel via multiprocessing."""

    def save_results(self, results: list[dict], filename: str) -> None:
        """Write to JSON and CSV."""
```

`io.py`:
```python
def results_to_json(results: list[dict], path: str) -> None:
    """Write full results with config + metrics to JSON.
    Includes principal.source and principal.demographics if present."""

def results_to_csv(results: list[dict], path: str) -> None:
    """Flat CSV: one row per run, columns = config params + metrics."""

def history_to_csv(history: SimulationHistory, path: str) -> None:
    """Agent-level CSV: one row per agent per round."""

def setup_logging(run_id: str, log_dir: str = "logs") -> str:
    """Structured JSON logging. Follow Olympus pattern from logging_utils.py."""
```

The four experiment scripts are standalone entry points:

`degroot_baseline.py`: 20 agents, DeGrootEngine only, Plenary, 50 rounds. Verify convergence to weighted mean. Plot opinion trajectories.

`bayesian_calibration.py`: 20 agents, BayesianEngine, vary `prior_precision` in [0.5, 1, 2, 5, 10]. Verify that high-precision agents change less. Target: 7-28% of agents change opinion (Butler calibration range).

`protocol_comparison.py`: Fixed population, compare Plenary vs Jury vs Assembly vs TownHall vs Committee. Same seed. DRI and distributional metrics per protocol.

`factorial_sweep.py`: Full factorial over protocol (5 levels) x group_composition (3) x facilitation (2) x group_building (5 levels) x engine (4). 10 replications. Total: 5 x 3 x 2 x 5 x 4 x 10 = 6,000 runs (~10 minutes). Outputs CSV for analysis.

**Acceptance criteria:**
- [ ] `ScenarioGenerator.generate()` produces scenarios with correct pro/con balance and attack density
- [ ] `barabas_consensual()` has >5:1 pro-to-con ratio; `barabas_non_consensual()` has ~1:1 ratio
- [ ] `FactorialDesign.generate_configs()` produces the correct number of configs (product of factor levels x replications)
- [ ] All configs within one factorial design use deterministic, non-colliding seeds
- [ ] `Runner.run_single()` returns a dict containing all config parameters and all metrics
- [ ] `Runner.run_batch()` produces results identical to running each config individually (determinism)
- [ ] `results_to_csv()` produces a valid CSV loadable by pandas with correct column names
- [ ] `history_to_csv()` has columns: run_id, agent_id, round, opinion, consideration_weights (JSON), dri
- [ ] Each experiment script runs to completion and produces output files
- [ ] `degroot_baseline.py` output shows monotonic variance decrease
- [ ] `pytest tests/test_scenarios.py tests/test_experiment.py` passes

**Depends on:** US-001, US-002, US-003, US-005
**Estimated complexity:** L

---

#### US-007: Benchmark calibration tests

**Why this story exists:** The model must reproduce known empirical and theoretical results to be credible. Four benchmarks from the literature serve as minimum validity constraints. If any benchmark fails, the model is miscalibrated. These are implemented as pytest tests, not experiment scripts, so they run in CI and catch regressions.

**What to change:**
- `tests/test_benchmarks.py`: Create. ~300 lines.

**How to implement:**

Each benchmark is a test function that constructs a specific scenario, runs it, and asserts on outcomes:

**Benchmark 1: DeGroot convergence theorem.**
Setup: n=20 agents with scalar opinions (single consideration, direction=+1), DeGrootEngine with mu=0.3, Plenary protocol, 100 rounds.
Assert: All agents' opinions converge to within epsilon=0.01 of the initial population mean. This is the mathematical baseline -- if it fails, the engine is broken.

**Benchmark 2: Barabas (2004) effect sizes.**
Setup: n=20 agents, BayesianEngine, `barabas_consensual()` scenario and `barabas_non_consensual()` scenario. Run CitizensAssembly protocol for 5 rounds.
Assert (consensual): Mean opinion shift in [+0.05, +0.25] (Barabas target: +0.14, with tolerance for rule-based model).
Assert (non-consensual): Mean opinion shift in [-0.05, +0.05] (Barabas: null effect).

**Benchmark 3: Jackman & Sniderman (2006) impossibility.**
Setup: n=20 agents, high initial consistency (c1=0.67), `jackman_sniderman_symmetric()` scenario. Run Plenary with ArgumentBasedEngine for 10 rounds.
Assert: Final consistency c2 is within [-0.05, +0.05] of initial consistency c1. No net improvement under symmetric arguments. If the model shows convergence here, the evaluation hook is biased.

**Benchmark 4: Caluwaerts et al. (2023) polarization base rates.**
Setup: n=20 agents, 10 replications each for heterogeneous-facilitated and homogeneous-unfacilitated conditions. BayesianEngine, CitizensAssembly protocol.
Assert (heterogeneous-facilitated): >40% of replications show depolarization (variance decrease). Target: 54.8%.
Assert (homogeneous-unfacilitated): >50% of replications show polarization (variance increase). Target: 63.6%.
Wider tolerance than the point estimates because n=20 is small and 10 replications produce noisy estimates.

**Acceptance criteria:**
- [ ] Benchmark 1 passes: DeGroot convergence to within 0.01 of mean
- [ ] Benchmark 2 passes: consensual shift in [+0.05, +0.25], non-consensual shift in [-0.05, +0.05]
- [ ] Benchmark 3 passes: consistency change in [-0.05, +0.05] under symmetric arguments
- [ ] Benchmark 4 passes: heterogeneous depolarization rate > 40%, homogeneous polarization rate > 50%
- [ ] All benchmarks are deterministic (fixed seeds) and run in <30 seconds total
- [ ] `pytest tests/test_benchmarks.py -v` passes

**Depends on:** US-001, US-002, US-003, US-004, US-005, US-006
**Estimated complexity:** M

---

## 4. Non-Goals & Scope Boundaries

This sprint explicitly will NOT:

- **Implement LLM agents.** This is a rule-based toy model. LLM integration is a future sprint. The CognitiveEngine architecture is the swap point -- write `LLMEngine(CognitiveEngine)` later.
- **Import real survey data.** Agents are initialized from configurable distributions, not from specific datasets. The `PrincipalProfile` data structure is planted as a seed; `AgentPopulation.from_survey()` is a future sprint.
- **Implement `vote()` as distinct from `opinion`.** In the rule-based model, vote=opinion. The vote/opinion distinction becomes meaningful only with LLM reflection in the principal-agent relationship.
- **Build a visualization layer.** The JS opinion-abm already has visualization. This sprint produces data (JSON/CSV) that can be visualized in notebooks or external tools.
- **Implement network topologies.** All protocols use complete graphs within groups (everyone hears everyone in their group). Social network structure (preferential attachment, small-world) is deferred.
- **Optimize for large N.** The model targets n=20-100 agents. O(n^2) DRI computation is acceptable. No parallelism, no GPU, no distributed computing.
- **Add Hydra or YAML config.** Python dataclasses are sufficient for a toy model. Config-file-driven experiments are a future refinement.
- **Implement Kurrild-Klitgaard & Brandt's full rational-choice model.** The CommitteePlenary protocol captures the subgroup structure, but the full utility/transaction-cost/reciprocity formalism is out of scope. It can be added as a new engine later.

---

## 5. Testing Strategy

### Existing test coverage
None. This is a new package.

### Tests to write per story

| Story | Test file | Coverage |
|-------|-----------|----------|
| US-001 | `test_agents.py`, `test_considerations.py` | Agent creation, opinion derivation (default + custom fn), PrincipalProfile, population generation, repertoire mechanics, attack graph |
| US-002 | `test_engines.py` | Each engine's voice/evaluate/reflect behavior, interface compliance, SimpleUpdateEngine default hooks, MixedEngine probability distribution |
| US-003 | `test_metrics.py` | DRI edge cases (identical, random, degenerate), alpha-fairness math, distributional formulas |
| US-004 | `test_moderator.py` | Group assignment variance, speaking equity, moderator intervention mechanics |
| US-005 | `test_protocols.py` | Protocol group formation, round execution, phase transitions (Assembly), engine hook call order, repertoire dynamics, determinism |
| US-006 | `test_scenarios.py`, `test_experiment.py` | Scenario generation parameters, hand-crafted fixtures, config generation, runner mechanics, IO |
| US-007 | `test_benchmarks.py` | Four empirical calibration targets |

### Manual verification
- Run `experiments/degroot_baseline.py` and inspect opinion convergence trajectory
- Run `experiments/protocol_comparison.py` and compare DRI across protocols
- Spot-check `factorial_sweep.py` output CSV for structural correctness

---

## 6. Rollback Plan

All work is in a new directory (`prospectus-work/sprint-01-toy-deliberation/`). No existing files are modified. Rollback = delete the directory.

---

## 7. Resolved Decisions

All open questions from the initial draft have been resolved through analysis:

1. **Opinion derivation function.** `sum(weight[c] * direction[c]) / len(repertoire)`, accepted as a swappable `Callable` parameter on `Agent` (default: `default_opinion_fn`). Sum-of-products is semantically correct (pro considerations raise opinion, con lower it), DRI-compatible, and DeGroot-degenerate when single consideration has direction=+1.

2. **Consideration generation.** Both: 2-3 hand-crafted scenarios for benchmark validation (Barabas consensual/non-consensual, Jackman-Sniderman symmetric) plus a `ScenarioGenerator` class with parameterized `n_considerations`, `pro_con_balance`, `attack_density`, `strength_distribution` for factorial sweeps. Same `Scenario` dataclass for both.

3. **Repertoire dynamics.** Static by default (Butler et al., ranked #2). Optional `repertoire_dynamics="learning"` parameter on protocols enables the Lustick & Miodownik mechanism. `Agent` stores repertoire as `dict[str, float]` from day one so dynamic mode requires no data structure change.

4. **Scale of factorial sweep.** Full factorial: 6,000 runs at ~100ms each = ~10 minutes. No computational reason for screening. Analysis investment goes into ANOVA decomposition of DRI variance, eta-squared effect sizes, and interaction plots.

5. **Package location.** `prospectus-work/sprint-01-toy-deliberation/`, sibling to existing prototypes (`llm-deliberation/`, `opinion-abm/`, `project-olympus/`). Avoids polluting the `prd-ralph/` git repo.

6. **Three-hook vs single-update interface.** Three-hook `CognitiveEngine` ABC (voice/evaluate/reflect) with `SimpleUpdateEngine` convenience base that collapses all three into a single `update()`. Net cost: ~20 lines. Net benefit: correct interface boundary for LLM integration, hook-level composability for mixed dynamics, isolated testability of evaluation logic (needed for Jackman-Sniderman benchmark).

7. **PrincipalProfile and vote().** `PrincipalProfile` added as a frozen dataclass in US-001 (`principal: PrincipalProfile | None = None`). Pure data, no behavioral implications. `vote()` deferred to LLM sprint -- in the rule-based model, vote=opinion is a tautology. The API design for `vote()` depends on understanding how LLM reflection handles the principal-agent tension, which is not yet known.
