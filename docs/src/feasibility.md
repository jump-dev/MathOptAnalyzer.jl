
# Feasibility Analysis

This module provides functionality to perform feasibility analysis on a JuMP model.
This module follows the main API and is activated by the struct:

```@docs
MathOptAnalyzer.Feasibility.Analyzer
```

The analysis will return issues of the abstract type:

```@docs
MathOptAnalyzer.Feasibility.AbstractFeasibilityIssue
```
Specifically, the possible issues are:

```@docs
MathOptAnalyzer.Feasibility.PrimalViolation
MathOptAnalyzer.Feasibility.DualConstraintViolation
MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation
MathOptAnalyzer.Feasibility.ComplemetarityViolation
MathOptAnalyzer.Feasibility.DualObjectiveMismatch
MathOptAnalyzer.Feasibility.PrimalObjectiveMismatch
MathOptAnalyzer.Feasibility.PrimalDualMismatch
MathOptAnalyzer.Feasibility.PrimalDualSolverMismatch
```

These issues are saved in the data structure that is returned from the
`MathOptAnalyzer.analyze` function:

```@docs
MathOptAnalyzer.Feasibility.Data
```