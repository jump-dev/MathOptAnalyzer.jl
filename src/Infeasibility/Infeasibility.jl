# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Infeasibility

import MathOptAnalyzer
import MathOptIIS as MOIIS
import MathOptInterface as MOI

include("structs.jl")
include("analyze.jl")
include("summarize.jl")

end  # module Infeasibility
