module VariableTemplates

debug() = false
using StaticArrays

export Vars, Grad

include("vars.jl")
include("varsindex.jl")
include("concretize.jl")
include("varsize.jl")
include("flattened_names.jl")
include("flattened_tup_chain.jl")
include("flattened_nt.jl")

abstract type AbstractVars{S, A, TC, TH} end
struct Vars{
    S,   # Variable index map
    A,   # Array
    TC,  # Tuple chain (tuple of Union{Symbol,Int})
    TH   # Tuple hash (NamedTuple): keys=hash of all tup-chains, values=(gid,len)
    } <: AbstractVars{S, A, TC, TH}
    array::A
end

struct Grad{
    S,   # Variable index map
    A,   # Array
    TC,  # Tuple chain (tuple of Union{Symbol,Int})
    TH   # Tuple hash (NamedTuple): keys=hash of all tup-chains, values=(gid,len)
    } <: AbstractVars{S, A, TC, TH}
    array::A
end

Base.parent(v::AbstractVars) = getfield(v, :array)
Base.eltype(v::AbstractVars) = eltype(parent(v))
Base.similar(v::AbstractVars{S, A, TC, TH}) where {S, A, TC, TH} =
    typeof(v)(similar(parent(v)))
Base.propertynames(v::AbstractVars{S}) where {S} = propertynames(S)

function Vars{S}(array) where {S}
    if S isa NamedTuple
        S_used = S
    else
        S_used = concretize(S)
    end
    TH = get_hash(S_used)
    A = typeof(array)
    TC = ()
    return Vars{S_used, A, TC, TH}(array)
end
function Grad{S}(array) where {S}
    if S isa NamedTuple
        S_used = S
    else
        S_used = concretize(S)
    end
    TH = get_hash(S_used)
    A = typeof(array)
    TC = ()
    return Grad{S_used, A, TC, TH}(array)
end

function get_hash(S)
    return flattened(
        S,
        :_,
        (pn,p) -> pn==:gid || pn == :type,
        (pn,p)->p,
        (nt)-> :gid in propertynames(nt) || :type in propertynames(nt))
end

#####
##### Internal methods
#####

get_tup_chain(v::AbstractVars{S,A,TC}) where {S,A,TC} = TC

get_val(::Val{T}) where {T} = T
get_val(::Type{Val{T}}) where {T} = T

# get length of result
get_len(::Type{Tuple{}}) = 0
get_len(::Type{Tuple{T}}) where {T<:NamedTuple} = get_len(parameters(T)[2])
get_len(::Type{Tuple{T}}) where {T} = get_len(T)
get_len(::Type{T}) where {T<:Real} = 1
get_len(::Type{T}) where {N,FT<:Real,T<:SVector{N,FT}} = N
get_len(::Type{T}) where {N,FT,T<:SArray{N,FT}} = N
get_len(::Type{T}) where {N,FT<:Real,M,T<:SHermitianCompact{N, FT, M}} = M

get_result(a, gid, ::Type{T}, ::Vars) where {T<:Real} = T(a[gid])
get_result(a, gid, ::Type{T}, ::Vars) where {S,FT<:Real,N,L,T<:SArray{S,FT,N,L},Vars} = T(a[gid:gid+L-1])
function get_result(a, gid, ::Type{T}, ::Vars) where {N,FT<:Real,M,T<:SHermitianCompact{N, FT, M}}
    return T(a[gid:gid+M-1])
end

get_result(a, gid, ::Type{T}, g::Grad) where {T<:Real} = T(a[1:grad_dim(g), gid])
function get_result(a, gid, ::Type{T}, g::Grad) where {S,FT<:Real,N,L,T<:SArray{S,FT,N,L}}
    M = grad_dim(g)
    MMatrix{M,L,FT}(a[1:M, gid:gid+L-1])
end
function get_result(a, gid, ::Type{T}, g::Grad) where {N,FT<:Real,P,T<:SHermitianCompact{N, FT, P}}
    M = grad_dim(g)
    return T(a[1:M, gid:gid+P-1])
end

function set_result!(a, gid, ::Type{T}, val, ::Vars) where {T<:Real}
    a[gid] = T(val)
end
function set_result!(a, gid, ::Type{T}, val, ::Vars) where {S,FT<:Real,N,L,T<:SArray{S,FT,N,L}}
    a[gid:gid+L-1] .= T(val)
end
function set_result!(a, gid, ::Type{T}, val, ::Vars) where {N,FT<:Real,P,T<:SHermitianCompact{N, FT, P}}
    a[gid:gid+P-1] .= T(val).lowertriangle
end

function set_result!(a, gid, ::Type{T}, val, g::Grad) where {T<:Real}
    M = grad_dim(g)
    a[1:M, gid] = T(val)
end
function set_result!(a, gid, ::Type{T}, val, g::Grad) where {S,FT<:Real,N,L,T<:SArray{S,FT,N,L}}
    M = grad_dim(g)
    a[1:M, gid:gid+L-1] .= MMatrix{M,L,FT}(val)
end
function set_result!(a, gid, ::Type{T}, val, g::Grad) where {N,FT<:Real,P,T<:SHermitianCompact{N, FT, P}}
    M = grad_dim(g)
    a[1:M, gid:gid+P-1] .= T(val).lowertriangle
end

Base.@propagate_inbounds function getproperty_generic(
    v::AbstractVars{S, A, TC, TH},
    tup_chain,
    S_new
) where {S, A, TC, TH}
    joined_tup_chain = join_tup_chain(tup_chain, :_)
    a = parent(v)
    if hasproperty(TH, joined_tup_chain)
        nt = getproperty(TH, joined_tup_chain)
        gid = get_val(nt.gid)
        type = get_val(nt.type)
        return get_result(a, gid, type, v)
    else
        if v isa Vars
            return Vars{S_new,A,tup_chain,TH}(a)
        else
            return Grad{S_new,A,tup_chain,TH}(a)
        end
    end
end

Base.@propagate_inbounds Base.getproperty(t::Tuple, tup_chain::Tuple) =
    Base.getproperty(Base.getindex(t, tup_chain[1]), tup_chain[2:end])

Base.@propagate_inbounds Base.getproperty(nt::NamedTuple, tup_chain::Tuple) =
    Base.getproperty(Base.getproperty(nt, tup_chain[1]), tup_chain[2:end])

Base.@propagate_inbounds Base.getproperty(nt::NamedTuple, syms::Tuple{S}) where {S} =
    Base.getproperty(nt, syms[1])

update_S(S, sym::Symbol) = getproperty(S, sym)
update_S(S, i::Int) = getindex(S, i)
update_S(S, tup_chain) = getproperty(S, tup_chain)

Base.@propagate_inbounds Base.getproperty(v::AbstractVars{S}, tup_chain::Tuple) where {S} =
    getproperty_generic(v, tup_chain, update_S(S, tup_chain))
Base.@propagate_inbounds Base.getproperty(v::AbstractVars{S, A, TC}, sym::Symbol) where {S, A, TC} =
    getproperty_generic(v, (TC..., sym), update_S(S, sym))

grad_dim(v::Grad{S,A}) where {S,A<:SubArray} = size(fieldtype(A, 1), 1)
grad_dim(v::Grad{S,A}) where {S,A} = size(A, 1)

Base.@propagate_inbounds function Base.setproperty!(
    v::AbstractVars{S, A, TC, TH},
    sym::Symbol,
    val
) where {S, A, TC, TH}
    sep = :_
    new_tup_chain = (TC..., sym)
    joined_tup_chain = join_tup_chain(new_tup_chain, sep)
    a = parent(v)
    if hasproperty(TH, joined_tup_chain)
        nt = getproperty(TH, joined_tup_chain)
        gid = get_val(nt.gid)
        type = get_val(nt.type)
        return set_result!(a, gid, type, val, v)
    else
        error("Cannot set property of non-concrete variable")
    end
end

Base.@propagate_inbounds @inline function Base.getindex(
    v::Vars{S, A, TC, TH},
    i::Int,
) where {S, A, TC, TH}
    sep = :_
    new_tup_chain = (TC..., i)
    joined_tup_chain = join_tup_chain(new_tup_chain, sep)
    a = parent(v)
    if hasproperty(TH, joined_tup_chain)
        nt = getproperty(TH, joined_tup_chain)
        gid = get_val(nt.gid)
        type = get_val(nt.type)
        return get_result(a, gid, type, v)
    else
        S_new = update_S(S, i)
        return Vars{S_new,A,new_tup_chain,TH}(a)
    end
end

Base.@propagate_inbounds @inline function Base.setindex!(
    v::AbstractVars{S, A, TC, TH},
    i::Int,
    val,
) where {S, A, TC, TH}
    sep = :_
    new_tup_chain = (TC..., i)
    joined_tup_chain = join_tup_chain(new_tup_chain, sep)
    a = parent(v)
    if hasproperty(TH, joined_tup_chain)
        nt = getproperty(TH, joined_tup_chain)
        gid = get_val(nt.gid)
        type = get_val(nt.type)
        return set_result!(a, gid, type, val, v)
    else
        error("Cannot set index of non-concrete variable")
    end
end

end # module
