
# Numerical Analysis

This module provides functionality to perform numerical analysis on a JuMP model.
This module follows the main API and is activated by the struct:

```@docs
ModelAnalyzer.Numerical.Analyzer
```

The analysis will return issues of the abstract type:

```@docs
ModelAnalyzer.Numerical.AbstractNumericalIssue
```

Specifically the possible issues are:

```@docs
ModelAnalyzer.Numerical.VariableNotInConstraints
ModelAnalyzer.Numerical.EmptyConstraint
ModelAnalyzer.Numerical.VariableBoundAsConstraint
ModelAnalyzer.Numerical.DenseConstraint
ModelAnalyzer.Numerical.SmallMatrixCoefficient
ModelAnalyzer.Numerical.LargeMatrixCoefficient
ModelAnalyzer.Numerical.SmallBoundCoefficient
ModelAnalyzer.Numerical.LargeBoundCoefficient
ModelAnalyzer.Numerical.SmallRHSCoefficient
ModelAnalyzer.Numerical.LargeRHSCoefficient
ModelAnalyzer.Numerical.SmallObjectiveCoefficient
ModelAnalyzer.Numerical.LargeObjectiveCoefficient
ModelAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient
ModelAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient
ModelAnalyzer.Numerical.NonconvexQuadraticConstraint
ModelAnalyzer.Numerical.SmallMatrixQuadraticCoefficient
ModelAnalyzer.Numerical.LargeMatrixQuadraticCoefficient
```

These issues are saved in the data structure that is returned from the `ModelAnalyzer.analyze` function:

```@docs
ModelAnalyzer.Numerical.Data
```