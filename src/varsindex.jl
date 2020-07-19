export varsindex, varsindices

"""
    varsindex(S, p::Symbol, [sp::Symbol...])

Return a range of indices corresponding to the property `p` and
(optionally) its subproperties `sp` based on the template type `S`.

# Examples
```julia-repl
julia> S = @vars(x::Float64, y::Float64)
julia> varsindex(S, :y)
2:2

julia> S = @vars(x::Float64, y::@vars(α::Float64, β::SVector{3, Float64}))
julia> varsindex(S, :y, :β)
3:5
```
"""
function varsindex(::Type{S}, insym::Symbol) where {S <: NamedTuple}
    offset = 0
    for varsym in fieldnames(S)
        T = fieldtype(S, varsym)
        if T <: Real
            offset += 1
            varrange = offset:offset
        elseif T <: SHermitianCompact
            LT = StaticArrays.lowertriangletype(T)
            N = length(LT)
            varrange = offset .+ (1:N)
            offset += N
        elseif T <: StaticArray
            N = length(T)
            varrange = offset .+ (1:N)
            offset += N
        else
            varrange = offset .+ (1:varsize(T))
            offset += varsize(T)
        end
        if insym == varsym
            return varrange
        end
    end
    error("symbol '$insym' not found")
end
Base.@propagate_inbounds function varsindex(
    ::Type{S},
    sym::Symbol,
    rest::Symbol...,
) where {S <: NamedTuple}
    varsindex(S, sym)[varsindex(fieldtype(S, sym), rest...)]
end

"""
    varsindices(S, ps::Tuple)
    varsindices(S, ps...)

Return a tuple of indices corresponding to the properties
specified by `ps` based on the template type `S`. Properties
can be specified using either symbols or strings.

# Examples
```julia-repl
julia> S = @vars(x::Float64, y::Float64, z::Float64)
julia> varsindices(S, (:x, :z))
(1, 3)

julia> S = @vars(x::Float64, y::@vars(α::Float64, β::SVector{3, Float64}))
julia> varsindices(S, "x", "y.β")
(1, 3, 4, 5)
```
"""
function varsindices(::Type{S}, vars::Tuple) where {S <: NamedTuple}
    indices = Int[]
    for var in vars
        splitvar = split(string(var), '.')
        append!(indices, collect(varsindex(S, map(Symbol, splitvar)...)))
    end
    Tuple(indices)
end
varsindices(::Type{S}, vars...) where {S <: NamedTuple} = varsindices(S, vars)
