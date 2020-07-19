using Test
using StaticArrays
using VariableTemplates
using InteractiveUtils

#### Test models
#
#   EmptyModel
#   ScalarModel
#   VectorModel
#   MatrixModel
#   CompositModel
#   NTupleContainingModel

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

# ------------------------------- Test concretize
m = EmptyModel()
st = vars_state(m, FT)
nt = concretize(st)
@test nt == NamedTuple()

m = ScalarModel()
st = vars_state(m, FT)
nt = concretize(st)
@test nt.x.type == Val(FT)
@test nt.x.gid == Val(1)
@test varsize(nt) == 1

Nv = 3
m = VectorModel{Nv}()
st = vars_state(m, FT)
nt = concretize(st)
@test nt.x.type == Val(SVector{Nv,FT})
@test nt.x.gid == Val(1)
@test varsize(nt) == 3

N = 3
M = 4
m = MatrixModel{N,M}()
st = vars_state(m, FT)
nt = concretize(st)
@test nt.x.type == Val(SHermitianCompact{N, FT, M})
@test nt.x.gid == Val(1)
@test varsize(nt) == M

Nv = 3
N = 3
M = 4
m = CompositModel{Nv,N,M}()
st = vars_state(m, FT)
nt = concretize(st)
@test nt.empty_model == NamedTuple()
@test nt.scalar_model.x.gid == Val(1)
@test nt.scalar_model.x.type == Val(FT)
@test nt.vector_model.x.gid == Val(2)
@test nt.vector_model.x.type == Val(SVector{Nv, FT})
@test nt.matrix_model.x.gid == Val(5)
@test nt.matrix_model.x.type == Val(SHermitianCompact{N, FT, M})
@test varsize(nt) == M+1+Nv

Nv = 3
N = 3
m = NTupleContainingModel{N,Nv}()
st = vars_state(m, FT)
for i in 1:N
    @test m.ntuple_model[i] isa NTupleModel
    @test m.ntuple_model[i].scalar_model isa ScalarModel
end
nt = concretize(st)
@test length(nt.ntuple_model) == N
for i in 1:N
    @test hasproperty(nt.ntuple_model[i], :scalar_model)
end


# ------------------------------- Test getproperty
m = ScalarModel()
st = vars_state(m, FT)
nt = concretize(st)
vs = varsize(nt)
a_global = collect(1:vs)
v = Vars{nt}(a_global)
@test v.x == FT(1)

Nv = 3
m = VectorModel{Nv}()
st = vars_state(m, FT)
nt = concretize(st)
vs = varsize(nt)
a_global = collect(1:vs)
v = Vars{nt}(a_global)
@test v.x == SVector{Nv,FT}(FT[1,2,3])

N = 3
M = 6
m = MatrixModel{N,M}()
st = vars_state(m, FT)
nt = concretize(st)
vs = varsize(nt)
a_global = collect(1:vs)
v = Vars{nt}(a_global)
@test v.x == SHermitianCompact{N,FT,M}(collect(1:1+M-1))

Nv = 3
N = 3
M = 6
m = CompositModel{Nv,N,M}()
st = vars_state(m, FT)
nt = concretize(st)
vs = varsize(nt)
a_global = collect(1:vs)
v = Vars{nt}(a_global)

scalar_model = v.scalar_model
@test VariableTemplates.get_tup_chain(scalar_model) == (:scalar_model,)
@test v.scalar_model.x == FT(1)

vector_model = v.vector_model
@test VariableTemplates.get_tup_chain(vector_model) == (:vector_model,)
@test v.vector_model.x == SVector{Nv,FT}([2,3,4])

matrix_model = v.matrix_model
@test VariableTemplates.get_tup_chain(matrix_model) == (:matrix_model,)
@test v.matrix_model.x == SHermitianCompact{N,FT,M}(collect(5:5+M-1))

Nv = 3
N = 3
m = NTupleContainingModel{N,Nv}()
st = vars_state(m, FT)
nt = concretize(st)
vs = varsize(nt)
a_global = collect(1:vs)
@test length(nt.ntuple_model) == N
for i in 1:N
    @test hasproperty(nt.ntuple_model[i], :scalar_model)
    @test hasproperty(nt.ntuple_model[i], :scalar_model)
end
v = Vars{nt}(a_global)

@test VariableTemplates.get_tup_chain(v.vector_model) == (:vector_model,)
@test v.vector_model.x == SVector{Nv,FT}([4,5,6])

@test VariableTemplates.get_tup_chain(v.scalar_model) == (:scalar_model,)
@test v.scalar_model.x == FT(7)

@test VariableTemplates.get_tup_chain(v.ntuple_model) == (:ntuple_model,)
for i in 1:N
    @test VariableTemplates.get_tup_chain(v.ntuple_model[i]) == (:ntuple_model, i)
end
for i in 1:N
    @test VariableTemplates.get_tup_chain(v.ntuple_model[i].scalar_model) == (:ntuple_model, i, :scalar_model)
end

for i in 1:N
    @test v.ntuple_model[i].scalar_model.x == FT(i)
    @test v.vector_model.x == SVector{Nv,FT}(N+1:N+Nv)
    @test v.scalar_model.x == FT(N+Nv+1)
end

fn = flattenednames(st)
@test fn[1] === "ntuple_model[1].scalar_model.x"
@test fn[2] === "ntuple_model[2].scalar_model.x"
@test fn[3] === "ntuple_model[3].scalar_model.x"
@test fn[4] === "vector_model.x[1]"
@test fn[5] === "vector_model.x[2]"
@test fn[6] === "vector_model.x[3]"
@test fn[7] === "scalar_model.x"

ftc = flattened_tup_chain(st)
@test ftc[1] === (:ntuple_model, 1, :scalar_model, :x)
@test ftc[2] === (:ntuple_model, 2, :scalar_model, :x)
@test ftc[3] === (:ntuple_model, 3, :scalar_model, :x)
@test ftc[4] === (:vector_model, :x)
@test ftc[5] === (:scalar_model, :x)

# getproperty with tup-chain
for i in 1:N
    @test v.ntuple_model[i].scalar_model.x == getproperty(v, (:ntuple_model, i, :scalar_model, :x))
    @test v.vector_model.x == getproperty(v, (:vector_model, :x))
    @test v.scalar_model.x == getproperty(v, (:scalar_model, :x))
end

# @code_typed v.ntuple_model[1].scalar_model.x
p = @code_typed getproperty(v, (:ntuple_model, 1, :scalar_model, :x))
p = @code_typed v.ntuple_model[1].scalar_model.x
@test p.first.inlineable == true
@test p.first.inferred == true
@test p.first.propagate_inbounds == true

