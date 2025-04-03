
# ModelAnalyzer main API

All the analysis modules in `ModelAnalyzer` follow the same main API.
The main function to perform an analysis is:

```@docs
ModelAnalyzer.analyze
```

Once the analysis is performed, the resulting data structure can be summarized
using:

```@docs
ModelAnalyzer.summarize
```

Alternatively, you can also query the types of issues found in the analysis
and summarize them individually. The following functions are useful for this:

```@docs
ModelAnalyzer.list_of_issue_types
ModelAnalyzer.list_of_issues
```
