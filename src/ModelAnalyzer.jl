# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module ModelAnalyzer

abstract type AbstractIssue end

abstract type AbstractData end

abstract type AbstractAnalyzer end

"""
    analyze(analyzer::AbstractAnalyzer, model::JuMP.Model; kwargs...)

Analyze a JuMP model using the specified analyzer.
Depending on the analyzer, this keyword arguments might vary.
This function will return an instance of `AbstractData` which contains the
results of the analysis that can be further summarized or queried for issues.

See [`summarize`](@ref), [`list_of_issues`](@ref), and
[`list_of_issue_types`](@ref).
"""
function analyze end

"""
    summarize([io::IO,] AbstractData; verbose = true, max_issues = 10, kwargs...)

Print a summary of the analysis results contained in `AbstractData` to the
specified IO stream. If no IO stream is provided, it defaults to `stdout`.
The `verbose` flag controls whether to print detailed information about each
issue (if `true`) or a concise summary (if `false`). The `max_issues` argument
controls the maximum number of issues to display in the summary. If there are
more issues than `max_issues`, only the first `max_issues` will be displayed.

    summarize([io::IO,] ::Type{T}; verbose = true) where {T<:AbstractIssue}

This variant allows summarizing information of a specific type `T` (which must
be a subtype of `AbstractIssue`). In the verbose case it will provide a text
explaning the issue. In the non-verbose case it will provide just the issue
name.

    summarize([io::IO,] issue::AbstractIssue; verbose = true)

This variant allows summarizing a single issue instance of type `AbstractIssue`.
"""
function summarize end

"""
    list_of_issue_types(data::AbstractData)

Return a vector of `DataType` containing the types of issues found in the
analysis results contained in `data`.
"""
function list_of_issue_types end

"""
    list_of_issues(data::AbstractData, issue_type::Type{T}) where {T<:AbstractIssue}

Return a vector of instances of `T` (which must be a subtype of `AbstractIssue`)
found in the analysis results contained in `data`. This allows you to retrieve
all instances of a specific issue type from the analysis results.
"""
function list_of_issues end

function summarize(io::IO, ::Type{T}; verbose = true) where {T<:AbstractIssue}
    if verbose
        return _verbose_summarize(io, T)
    else
        return _summarize(io, T)
    end
end

function summarize(io::IO, issue::AbstractIssue; verbose = true)
    if verbose
        return _verbose_summarize(io, issue)
    else
        return _summarize(io, issue)
    end
end

function summarize(
    io::IO,
    issues::Vector{T};
    verbose = true,
    max_issues = 10,
) where {T<:AbstractIssue}
    summarize(io, T, verbose = verbose)
    print(io, "\n## Number of issues\n\n")
    print(io, "Found ", length(issues), " issues")
    print(io, "\n\n## List of issues\n\n")
    if length(issues) > max_issues
        print(
            io,
            "Showing first ",
            max_issues,
            " issues " * "($(length(issues) - max_issues) issues ommitted)\n\n",
        )
    end
    for issue in first(issues, max_issues)
        print(io, " * ")
        summarize(io, issue, verbose = verbose)
        print(io, "\n")
    end
    return
end

function summarize(data::AbstractData; kwargs...)
    return summarize(stdout, data; kwargs...)
end

function _verbose_summarize end
function _summarize end

include("numerical.jl")
include("feasibility.jl")
include("infeasibility.jl")

end
