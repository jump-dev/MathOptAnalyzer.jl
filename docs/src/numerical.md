
# Numerical Analysis

This module provides functionality to perform numerical analysis on a JuMP model.
This module follows the main API and is activated by the struct:

```@docs
MathOptAnalyzer.Numerical.Analyzer
```

The analysis will return issues of the abstract type:

```@docs
MathOptAnalyzer.Numerical.AbstractNumericalIssue
```

Specifically the possible issues are:

```@docs
MathOptAnalyzer.Numerical.VariableNotInConstraints
MathOptAnalyzer.Numerical.EmptyConstraint
MathOptAnalyzer.Numerical.VariableBoundAsConstraint
MathOptAnalyzer.Numerical.DenseConstraint
MathOptAnalyzer.Numerical.SmallMatrixCoefficient
MathOptAnalyzer.Numerical.LargeMatrixCoefficient
MathOptAnalyzer.Numerical.SmallBoundCoefficient
MathOptAnalyzer.Numerical.LargeBoundCoefficient
MathOptAnalyzer.Numerical.SmallRHSCoefficient
MathOptAnalyzer.Numerical.LargeRHSCoefficient
MathOptAnalyzer.Numerical.SmallObjectiveCoefficient
MathOptAnalyzer.Numerical.LargeObjectiveCoefficient
MathOptAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient
MathOptAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient
MathOptAnalyzer.Numerical.SmallMatrixQuadraticCoefficient
MathOptAnalyzer.Numerical.LargeMatrixQuadraticCoefficient
MathOptAnalyzer.Numerical.NonconvexQuadraticObjective
MathOptAnalyzer.Numerical.NonconvexQuadraticConstraint
```

These issues are saved in the data structure that is returned from the `MathOptAnalyzer.analyze` function:

```@docs
MathOptAnalyzer.Numerical.Data
```