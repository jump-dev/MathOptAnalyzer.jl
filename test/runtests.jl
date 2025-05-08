# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

using Test

@testset "ModelAnalyzer" begin
    for file in readdir(@__DIR__)
        if !endswith(file, ".jl") || file in ("runtests.jl",)
            continue
        end
        @testset "$file" begin
            include(file)
        end
    end
end
