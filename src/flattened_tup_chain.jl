export flattened_tup_chain

flattened_tup_chain(::Type{NamedTuple{(), Tuple{}}}; prefix = (Symbol(),)) = ()
flattened_tup_chain(::Type{T}; prefix = (Symbol(),)) where {T <: Real} = (prefix,)
flattened_tup_chain(::Type{T}; prefix = (Symbol(),)) where {T <: SVector} = (prefix,)
flattened_tup_chain(::Type{T}; prefix = (Symbol(),)) where {T <: SHermitianCompact} = (prefix,)

"""
    flattened_tup_chain(::Type{T}) where {T <: Union{NamedTuple,NTuple}}


"""
function flattened_tup_chain(::Type{T}; prefix = (Symbol(),)) where {T <: Union{NamedTuple,NTuple}}
    map(1:fieldcount(T)) do i
        Ti = fieldtype(T, i)
        name = fieldname(T, i)
        sname = name isa Int ? name : Symbol(name)
        flattened_tup_chain(
            Ti,
            prefix = prefix == (Symbol(),) ? (sname,) : (prefix..., sname),
        )
    end |>
    Iterators.flatten |>
    collect
end
