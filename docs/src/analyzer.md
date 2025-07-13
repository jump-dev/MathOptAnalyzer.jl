
# MathOptAnalyzer main API

All the analysis modules in `MathOptAnalyzer` follow the same main API.
The main function to perform an analysis is:

```@docs
MathOptAnalyzer.analyze
```

Once the analysis is performed, the resulting data structure can be summarized
using:

```@docs
MathOptAnalyzer.summarize
```

Alternatively, you can also query the types of issues found in the analysis
and summarize them individually. The following functions are useful for this:

```@docs
MathOptAnalyzer.list_of_issue_types
MathOptAnalyzer.list_of_issues
```

It is possible to extract data from the issues with the methods:

```@docs
MathOptAnalyzer.variables
MathOptAnalyzer.variable
MathOptAnalyzer.constraints
MathOptAnalyzer.constraint
MathOptAnalyzer.set
MathOptAnalyzer.values
MathOptAnalyzer.value
```
