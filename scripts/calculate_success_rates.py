#!/usr/bin/env python3

import sys
import json
from pathlib import Path
import importlib.util
from typing import Dict, Any, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
EVALUATION_ROOT = REPO_ROOT / "evaluation"
NUMERICAL_EVAL_PATHS = [
    REPO_ROOT / "eval_scripts" / "cogs" / "numerical_eval.py",
    REPO_ROOT / "eval_scripts" / "othello" / "numerical_eval.py",
]
TASK_TO_NUMERICAL_EVAL = {path.parent.name: path for path in NUMERICAL_EVAL_PATHS}
TASKS = list(TASK_TO_NUMERICAL_EVAL)

# List of hint types
HINT_TYPES = ["default"]

def get_task_result(task: str, hint_type: str, run_number: int, agent_name: str) -> Tuple[bool, Dict[str, Any]]:
    """
    Returns the result of running numerical_eval.py for a specific task, hint type, and run number.
    
    Args:
        task: Task name
        hint_type: Hint type (default, hints, more_detailed_hints)
        run_number: Run number
        
    Returns:
        Tuple containing success status and result data
    """
    try:
        # Import the numerical_eval.py module for the task
        module_path = TASK_TO_NUMERICAL_EVAL.get(task)
        
        if module_path is None:
            return False, {"error": f"No numerical_eval.py configured for task {task}"}

        if not module_path.exists():
            print(f"Warning: {module_path} does not exist")
            return False, {"error": f"Module {module_path} does not exist"}
        
        # Import the module
        spec = importlib.util.spec_from_file_location(f"{task}_numerical_eval", module_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        
        # Get the run directory
        run_dir = EVALUATION_ROOT / agent_name / task / hint_type / f"run{run_number}"

        # Check if the run directory exists
        if not run_dir.exists():
            return False, {"error": f"Run directory {run_dir} does not exist"}
        
        # Call the task's numerical evaluator with the expected input shape.
        if task == "cogs":
            txt_files = list(run_dir.glob("*.txt"))
            if txt_files:
                result = module.main(str(txt_files[0]))
            else:
                result = {"error": "No text files found"}
        elif task == "othello":
            ckpts_dir = run_dir / "ckpts"
            if ckpts_dir.exists():
                result = module.main(str(ckpts_dir))
            else:
                result = {"error": f"Missing ckpts directory: {ckpts_dir}"}
        else:
            return False, {"error": f"Unsupported task {task}"}
        
        # Check if the result is a dictionary
        if not isinstance(result, dict):
            # If it's a boolean, wrap it in a dictionary
            if isinstance(result, bool):
                result = {"success": result}
            # If it's something else, convert to string and wrap
            else:
                result = {"result": str(result)}
        
        # Determine success based on task-specific criteria.
        if task == "cogs":
            # For cogs, check right_range
            success = result.get("right_range", False)
        elif task == "othello":
            # For othello, check all_layers_in_range
            success = result.get("all_layers_in_range", False)
        else:
            success = False
        
        return success, result
    except Exception as e:
        # Count any exception as a failure and return error details
        print(f"Error executing numerical_eval.py for {task}/{hint_type}/run{run_number}: {e}")
        return False, {"error": str(e), "exception": True}

def calculate_success_rate(task: str, agent_name: str) -> Dict[str, Any]:
    """
    Calculates success rates for a specific task across different hint types.
    
    Args:
        task: Task name
        
    Returns:
        Dictionary containing success rates for each hint type
    """
    results = {}
    
    # Detect max_run once across all hint types for this agent/task
    task_base = EVALUATION_ROOT / agent_name / task
    max_run = 0
    if task_base.exists():
        for hint_dir in task_base.iterdir():
            if hint_dir.is_dir():
                for d in hint_dir.iterdir():
                    if d.is_dir() and d.name.startswith("run"):
                        try:
                            num = int(d.name[3:])
                            if num > max_run:
                                max_run = num
                        except ValueError:
                            pass
    if max_run == 0:
        max_run = 5  # fallback only if entire task dir is missing

    for hint_type in HINT_TYPES:
        success_count = 0
        total_runs = 0
        run_results = []
        
        # Collect results for each run
        for run_number in range(1, max_run + 1):
            success, result = get_task_result(task, hint_type, run_number, agent_name)
            # Always count the run, treat errors as failures
            total_runs += 1
            if success:
                success_count += 1
            run_results.append({
                "run": run_number,
                "success": success,
                "details": result
            })
        
        # Calculate success rate
        success_rate = (success_count / total_runs) * 100 if total_runs > 0 else 0
        
        results[hint_type] = {
            "success_rate": success_rate,
            "success_count": success_count,
            "total_runs": total_runs,
            "run_results": run_results
        }
    
    return results

def main() -> None:
    """
    Calculates success rates for all tasks and saves results to a JSON file.
    """
    agent_name = "claude_code"
    if len(sys.argv) > 1:
        agent_name = sys.argv[1]
    
    result_dir_name = "results"
    if len(sys.argv) > 2:
        result_dir_name = sys.argv[2]
    
    print(f"Using agent name: {agent_name}")
    all_results = {}
    
    for task in TASKS:
        print(f"Processing task: {task}")
        task_results = calculate_success_rate(task, agent_name)
        all_results[task] = task_results
    
    # Calculate overall summary
    summary = {"overall": {}}
    for hint_type in HINT_TYPES:
        total_success = 0
        total_runs = 0
        
        for task in TASKS:
            if hint_type in all_results[task]:
                total_success += all_results[task][hint_type]["success_count"]
                total_runs += all_results[task][hint_type]["total_runs"]
        
        overall_success_rate = (total_success / total_runs) * 100 if total_runs > 0 else 0
        summary["overall"][hint_type] = {
            "success_rate": overall_success_rate,
            "success_count": total_success,
            "total_runs": total_runs
        }
    
    # Save results to JSON file
    output_dir = REPO_ROOT / "evaluation_results" / agent_name / result_dir_name

    output_dir.mkdir(parents=True, exist_ok=True)
    
    output_path = output_dir / f"success_rates_{agent_name}.json"
    
    # Convert NumPy types to Python native types for JSON serialization
    def convert_to_native_types(obj):
        if isinstance(obj, dict):
            return {k: convert_to_native_types(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [convert_to_native_types(item) for item in obj]
        elif hasattr(obj, "item") and callable(getattr(obj, "item")):
            # Handle NumPy types like bool_, int64, float64, etc.
            return obj.item()
        else:
            return obj
    
    # Convert all results to native Python types
    all_results_native = convert_to_native_types(all_results)
    summary_native = convert_to_native_types(summary)
    
    with open(output_path, "w") as f:
        json.dump({"tasks": all_results_native, "summary": summary_native}, f, indent=2)
    
    # Print results
    print("\n===== Task Success Rates =====")
    for task in TASKS:
        print(f"\n{task}:")
        for hint_type, hint_results in all_results[task].items():
            rate = hint_results["success_rate"]
            count = hint_results["success_count"]
            total = hint_results["total_runs"]
            print(f"  {hint_type}: {rate:.2f}% ({count}/{total})")
    
    print(f"Results saved to {output_path}")
    print("\n===== Overall Success Rates =====")
    for hint_type, hint_results in summary["overall"].items():
        rate = hint_results["success_rate"]
        count = hint_results["success_count"]
        total = hint_results["total_runs"]
        print(f"{hint_type}: {rate:.2f}% ({count}/{total})")

if __name__ == "__main__":
    main()
