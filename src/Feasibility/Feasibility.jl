# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Feasibility

import Dualization
import MathOptInterface as MOI
import MathOptAnalyzer
import Printf

include("structs.jl")
include("analyze.jl")
include("summarize.jl")

end  # module Feasibility
