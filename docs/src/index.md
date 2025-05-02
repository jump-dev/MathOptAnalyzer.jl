```@meta
CurrentModule = ModelAnalyzer
DocTestSetup = quote
    using ModelAnalyzer
end
```

# ModelAnalyzer.jl

This package provides tools for analyzing (and debugging)
[JuMP](https://github.com/jump-dev/JuMP.jl) models.

Three main functionalities are provided:

 1. **Numerical Analysis**: Check for numerical issues in the model, such as
    large and small coefficients, empty constraints, non-convex quadratic
    functions.
 2. **Feasibility Analysis**: Given an optimized model, or a candidate solution,
    check if the solutions is feasible and optimal (when possible). This
    includes checking the feasibility of the primal model and also the dual
    model (if available). Complementary slackness conditions are also checked
    (if applicable).
 3. **Infeasibility Analysis**: Given an unsolved of solved model, three steps
    are made to check for infeasibility:
    - Check bounds, integers and binaries consistency is also checked at this
      point.
    - Propagate bounds in constraints individually, to check if each constraint
      is infeasible given the current variable bounds. This is only done if
      bounds are ok.
    - Run an IIS (Irreducible Inconsistent Subsystem / irreducible infeasible
      sets) resolver algorithm to find a minimal infeasible subset of
      constraints. This is only done if no issues are found in the previous two
      steps.

## Installation

You can install the package using the Julia package manager. In the Julia REPL,
run:

```julia
using Pkg
Pkg.add(url = "https://github.com/jump-dev/ModelAnalyzer.jl")
```

## Usage

### Basic usage

Here is a simple example of how to use the package:

```julia
using JuMP
using ModelAnalyzer
using HiGHS # or any other supported solver
# Create a simple JuMP model
model = Model(HiGHS.Optimizer)
@variable(model, x >= 0)
@variable(model, y >= 0)
@constraint(model, c1, 2x + 3y == 5)
@constraint(model, c2, x + 2y <= 3)
@objective(model, Min, x + y)
# Optimize the model
optimize!(model)

# either

# Perform a numerical analysis of the model
data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
# print report
ModelAnalyzer.summarize(data)

# or

# Check for solution feasibility and optimality
data = ModelAnalyzer.analyze(ModelAnalyzer.Feasibility.Analyzer(), model)
# print report
ModelAnalyzer.summarize(data)

# or

# Infeasibility analysis (if the model was infeasible)
data = ModelAnalyzer.analyze(
    ModelAnalyzer.Infeasibility.Analyzer(),
    model,
    optimizer = HiGHS.Optimizer,
)

# print report to the screen
ModelAnalyzer.summarize(data)

# or print ehte report to a file

# open a file
open("my_report.txt", "w") do io
    # print report
    ModelAnalyzer.summarize(io, data)
end
```

The `ModelAnalyzer.analyze(...)` function can always take the keyword arguments:
 * `verbose = false` to condense the print output.
 * `max_issues = n` to limit the maximum number of issues to report for each
   type.

For certain analysis modes, the `summarize` function can take additional
arguments.

### Advanced usage

After any `ModelAnalyzer.analyze(...)` call is performed, the resulting data
structure can be summarized using `ModelAnalyzer.summarize(data)` as show above,
or it can be further inspected programmatically.

```julia
# given a `data` object obtained from `ModelAnalyzer.analyze(...)`

# query the types os issues found in the analysis
list = ModelAnalyzer.list_of_issue_types(data)

# information about the types of issues found can be printed out
ModelAnalyzer.summarize(data, list[1])

# for each issue type, you can get the actual issues found in the analysis
issues = ModelAnalyzer.list_of_issues(data, list[1])

# the list of issues of the given type can be summarized with:
ModelAnalyzer.summarize(data, issues)

# individual issues can also be summarized
ModelAnalyzer.summarize(data, issues[1])
```
