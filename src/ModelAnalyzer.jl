# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module ModelAnalyzer

abstract type AbstractIssue end

abstract type AbstractData end

abstract type AbstractAnalyzer end

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
    max_issues = typemax(Int),
) where {T<:AbstractIssue}
    summarize(io, T, verbose = verbose)
    print(io, "\n## Number of issues\n\n")
    print(io, "Found ", length(issues), " issues")
    print(io, "\n\n## List of issues\n\n")
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

function analyze end
function list_of_issues end
function list_of_issue_types end

function _verbose_summarize end
function _summarize end

include("numerical.jl")
include("feasibility.jl")
include("infeasibility.jl")

end
