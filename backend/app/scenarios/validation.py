"""Publication-time graph validation for scenario configurations."""

from collections.abc import Iterable

from app.scenarios.schemas import ScenarioConfig, TransitionTargetKind


class ScenarioValidationError(ValueError):
    """Report all publication-blocking scenario configuration issues."""

    def __init__(self, issues: Iterable[str]) -> None:
        self.issues = tuple(issues)
        super().__init__("; ".join(self.issues))


def _reachable_stage_ids(config: ScenarioConfig, stage_ids: set[str]) -> set[str]:
    if config.initial_stage_id not in stage_ids:
        return set()

    reachable: set[str] = set()
    pending = [config.initial_stage_id]
    while pending:
        stage_id = pending.pop()
        if stage_id in reachable:
            continue
        reachable.add(stage_id)

        stage = next(stage for stage in config.stages if stage.stage_id == stage_id)
        pending.extend(
            choice.transition.target_id
            for choice in stage.choices
            if choice.transition.target_kind == TransitionTargetKind.STAGE
            and choice.transition.target_id in stage_ids
        )

    return reachable


def _stages_with_finite_end_path(config: ScenarioConfig, stage_ids: set[str]) -> set[str]:
    stages_with_exit = {
        stage.stage_id
        for stage in config.stages
        if any(
            choice.transition.target_kind == TransitionTargetKind.END for choice in stage.choices
        )
    }

    changed = True
    while changed:
        changed = False
        for stage in config.stages:
            if stage.stage_id in stages_with_exit:
                continue
            if any(
                choice.transition.target_kind == TransitionTargetKind.STAGE
                and choice.transition.target_id in stage_ids
                and choice.transition.target_id in stages_with_exit
                for choice in stage.choices
            ):
                stages_with_exit.add(stage.stage_id)
                changed = True

    return stages_with_exit


def _stages_in_cycles(config: ScenarioConfig, stage_ids: set[str]) -> set[str]:
    adjacency = {
        stage.stage_id: [
            choice.transition.target_id
            for choice in stage.choices
            if choice.transition.target_kind == TransitionTargetKind.STAGE
            and choice.transition.target_id in stage_ids
        ]
        for stage in config.stages
    }
    state: dict[str, int] = {}
    stack: list[str] = []
    stack_indexes: dict[str, int] = {}
    cyclic_stage_ids: set[str] = set()

    def visit(stage_id: str) -> None:
        state[stage_id] = 1
        stack_indexes[stage_id] = len(stack)
        stack.append(stage_id)

        for target_id in adjacency[stage_id]:
            if state.get(target_id, 0) == 0:
                visit(target_id)
            elif state[target_id] == 1:
                cyclic_stage_ids.update(stack[stack_indexes[target_id] :])

        stack.pop()
        stack_indexes.pop(stage_id)
        state[stage_id] = 2

    for stage in config.stages:
        if state.get(stage.stage_id, 0) == 0:
            visit(stage.stage_id)

    return cyclic_stage_ids


def _is_pressure_stage(risk_points: list[str]) -> bool:
    return any("pressure" in risk_point for risk_point in risk_points)


def validate_scenario_config(config: ScenarioConfig) -> None:
    """Reject scenario graphs that are unsafe or cannot finish normally."""

    issues: list[str] = []
    stage_ids = {stage.stage_id for stage in config.stages}
    end_state_ids = {condition.end_state.value for condition in config.end_conditions}

    if config.initial_stage_id not in stage_ids:
        issues.append(f"unknown initial stage target '{config.initial_stage_id}'")

    for stage in config.stages:
        for choice in stage.choices:
            transition = choice.transition
            if (
                transition.target_kind == TransitionTargetKind.STAGE
                and transition.target_id not in stage_ids
            ):
                issues.append(
                    f"unknown stage target '{transition.target_id}' "
                    f"from stage '{stage.stage_id}' choice '{choice.choice_id}'"
                )
            elif (
                transition.target_kind == TransitionTargetKind.END
                and transition.target_id not in end_state_ids
            ):
                issues.append(
                    f"unknown end target '{transition.target_id}' "
                    f"from stage '{stage.stage_id}' choice '{choice.choice_id}'"
                )

    if config.initial_stage_id in stage_ids:
        reachable_stage_ids = _reachable_stage_ids(config, stage_ids)
        for stage in config.stages:
            if stage.stage_id not in reachable_stage_ids:
                issues.append(f"unreachable stage '{stage.stage_id}'")

    stages_with_end_path = _stages_with_finite_end_path(config, stage_ids)
    for stage in config.stages:
        if stage.stage_id not in stages_with_end_path:
            issues.append(f"no finite end path from stage '{stage.stage_id}'")

    cyclic_stage_ids = _stages_in_cycles(config, stage_ids)
    for stage in config.stages:
        if stage.stage_id in cyclic_stage_ids:
            issues.append(f"non-terminating cycle includes stage '{stage.stage_id}'")

    pressure_prompt_count = sum(_is_pressure_stage(stage.risk_points) for stage in config.stages)
    pressure_prompt_limit = config.content_safety.max_pressure_prompts
    if pressure_prompt_count > pressure_prompt_limit:
        issues.append(
            "pressure prompt limit exceeded: "
            f"found {pressure_prompt_count}, allowed {pressure_prompt_limit}"
        )

    if issues:
        raise ScenarioValidationError(issues)
