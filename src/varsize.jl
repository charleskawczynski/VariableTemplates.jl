export varsize

"""
    varsize(S)

The number of elements specified by the template type `S`.
"""
varsize(::Type{T}) where {T <: Real} = 1
varsize(::Type{Tuple{}}) = 0
varsize(::Type{NamedTuple{(), Tuple{}}}) = 0
varsize(::Type{SVector{N, T}}) where {N, T <: Real} = N

@generated function varsize(::Type{S}) where {S}
    types = fieldtypes(S)
    isempty(types) ? 0 : sum(varsize, types)
end

varsize(nt::Tuple) = sum([varsize(nt[i]) for i in 1:length(nt)])

function varsize(nt::NamedTuple)
    if Symbol(:type) in keys(nt)
        return sum(get_len(get_val(nt.type)))
    else
        v = values(nt)
        if v isa Tuple{}
            return 0
        else
            return sum(varsize.(v))
        end
    end
end
