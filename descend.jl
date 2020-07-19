using Test
using Cthulhu
using StaticArrays
using VariableTemplates

abstract type OneLayerModel end

struct EmptyModel <: OneLayerModel end
vars_state(m::EmptyModel, T) = @vars()

struct ScalarModel <: OneLayerModel end
vars_state(m::ScalarModel, T) = @vars(x::T)

struct VectorModel{N} <: OneLayerModel end
vars_state(m::VectorModel{N}, T) where {N} = @vars(x::SVector{N, T})

struct MatrixModel{N,M} <: OneLayerModel end
vars_state(m::MatrixModel{N,M}, T) where {N,M} = @vars(x::SHermitianCompact{N, T, M})

abstract type TwoLayerModel end

Base.@kwdef struct CompositModel{Nv,N,M} <: TwoLayerModel
    empty_model = EmptyModel()
    scalar_model = ScalarModel()
    vector_model = VectorModel{Nv}()
    matrix_model = MatrixModel{N,M}()
end
function vars_state(m::CompositModel, T)
    @vars begin
        empty_model::vars_state(m.empty_model, T)
        scalar_model::vars_state(m.scalar_model, T)
        vector_model::vars_state(m.vector_model, T)
        matrix_model::vars_state(m.matrix_model, T)
    end
end

Base.@kwdef struct NTupleModel <: OneLayerModel
    scalar_model = ScalarModel()
end

function vars_state(m::NTupleModel, T)
    @vars begin
        scalar_model::vars_state(m.scalar_model, T)
    end
end

vars_state(m::NTuple{N, NTupleModel}, FT) where {N} =
    Tuple{ntuple(i -> vars_state(m[i], FT), N)...}

Base.@kwdef struct NTupleContainingModel{N,Nv} <: TwoLayerModel
    ntuple_model = ntuple(i -> NTupleModel(), N)
    vector_model = VectorModel{Nv}()
    scalar_model = ScalarModel()
end

function vars_state(m::NTupleContainingModel, T)
    @vars begin
        ntuple_model::vars_state(m.ntuple_model, T)
        vector_model::vars_state(m.vector_model, T)
        scalar_model::vars_state(m.scalar_model, T)
    end
end

FT = Float32;

Nv = 3
N = 3
m = NTupleContainingModel{N,Nv}()
st = vars_state(m, FT)

@descend concretize(st)

