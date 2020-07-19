using Test
using StaticArrays
using VariableTemplates

@testset "Variable Templates" begin
    include("base_functionality.jl")
    include("test_simple_models.jl")
    include("test_complex_models.jl")
    include("test_varsindex.jl")
end
