export concretize

untype(::Type{T}) where {T} = T
parameters(::Type{T}) where {T} = T.parameters
parameters(t) = t.parameters

function concretize(ntt::Core.SimpleVector, gid) # typeof(ntt)==Core.SimpleVector
    k_lev = ntt[1]
    v_lev = tuple((
    begin
        if v <: NamedTuple
            val, gid = concretize(parameters(v), gid)
        elseif v <: NTuple
            v_ntuple = parameters(v)
            N = length(v_ntuple)
            val = ntuple(i->begin
                nt, gid = concretize(parameters(v_ntuple[i]), gid)
                nt
                end
                , N)
        else
            val = (type=Val(v), gid=Val(gid))
            gid+=get_len(v)
        end
        val
    end
    for v in parameters(untype(ntt[2])))...)
    nt = (; zip(k_lev, v_lev)...)
    return (nt, gid)
end

"""
    concretize(ntt::Type{NamedTuple}, gid=1)

A nested NamedTuple given a nested
NamedTuple type `ntt`, whose values
are types. The concretized nested
NamedTuple is a NamedTuple with
`type` (the original type values)
and `gid`, a global index, which
is incremented by `get_len` of the
type.
"""
function concretize(ntt::Type{T}, gid=1) where {T} # typeof(ntt)==DataType
    nt,gid = concretize(parameters(ntt), gid)
    return nt
end
