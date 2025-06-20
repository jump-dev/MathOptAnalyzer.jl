# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Numerical

import LinearAlgebra
import MathOptInterface as MOI
import ModelAnalyzer
import Printf

include("structs.jl")
include("analyze.jl")
include("summarize.jl")

end  # module Numerical
