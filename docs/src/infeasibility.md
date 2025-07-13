
# Infeasibility Analysis

This module provides functionality to perform infeasibility analysis on a JuMP model.
This module follows the main API and is activated by the struct:

```@docs
MathOptAnalyzer.Infeasibility.Analyzer
```

The analysis will return issues of the abstract type:

```@docs
MathOptAnalyzer.Infeasibility.AbstractInfeasibilitylIssue
```

Specifically, the possible issues are:

```@docs
MathOptAnalyzer.Infeasibility.InfeasibleBounds
MathOptAnalyzer.Infeasibility.InfeasibleIntegrality
MathOptAnalyzer.Infeasibility.InfeasibleConstraintRange
MathOptAnalyzer.Infeasibility.IrreducibleInfeasibleSubset
```

These issues are saved in the data structure that is returned from the
`MathOptAnalyzer.analyze` function:

```@docs
MathOptAnalyzer.Infeasibility.Data
```