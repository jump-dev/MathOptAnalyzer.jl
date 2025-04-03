
# Infeasibility Analysis

This module provides functionality to perform infeasibility analysis on a JuMP model.
This module follows the main API and is activated by the struct:

```@docs
ModelAnalyzer.Infeasibility.Analyzer
```

The analysis will return issues of the abstract type:

```@docs
ModelAnalyzer.Infeasibility.AbstractInfeasibilityIssue
```

Specifically, the possible issues are:

```@docs
ModelAnalyzer.Infeasibility.PrimalInfeasibility
ModelAnalyzer.Infeasibility.PrimalInfeasibility
ModelAnalyzer.Infeasibility.PrimalInfeasibility
ModelAnalyzer.Infeasibility.PrimalInfeasibility
```

These issues are saved in the data structure that is returned from the `ModelAnalyzer.analyze` function:

```@docs
ModelAnalyzer.Infeasibility.Data
```