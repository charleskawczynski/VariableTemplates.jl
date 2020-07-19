join_tup_chain(tup_chain, separator::Symbol) = Symbol(join(tup_chain, separator)...)

function flattened!(
        k_all,
        v_all,
        nt::Union{NamedTuple,Tuple},
        tup_chain,
        separator,
        filter_leaves,
        process_leaves,
        stop_at_branch
    )
    if stop_at_branch(nt)
        push!(k_all, join_tup_chain(tup_chain, separator))
        k_leaf = []
        v_leaf = []
        for pn in propertynames(nt)
            p = getproperty(nt, pn)
            if filter_leaves(pn, p)
                push!(k_leaf, pn)
                push!(v_leaf, process_leaves(pn, p))
            end
        end
        push!(v_all, (; zip(k_leaf, v_leaf)...))
    else
        for pn in propertynames(nt)
            p = getproperty(nt, pn)
            tup_chain_new = (tup_chain..., pn)
            if filter_leaves(pn, p)
                push!(k_all, join_tup_chain(tup_chain_new, separator))
                push!(v_all, process_leaves(pn, p))
            end
            flattened!(k_all, v_all, p, tup_chain_new, separator,
                filter_leaves, process_leaves, stop_at_branch)
        end
    end
end

"""
    flattened(nt::NamedTuple,
              separator::Symbol = :_,
              filter_leaves::Function = (pn,p) -> true,
              process_leaves::Function = (pn,p) -> p)

A flattened namedtuple, given a nested
namedtuple, which also may contain Tuples
of namedtuples.

The leaves of the nested namedtuples
can be filtered with the function argument
`filter_leaves`, and processed with the
function argument `process_leaves`.

# Example
```julia
julia> nt = (x = 1, a = (y = 2, z = 3, b = ((a = 1,), (a = 2,), (a = 3,))));

julia> fnt = flattened(nt, :_);

julia> keys(fnt)
(:x, :a, :a_y, :a_z, :a_b, :a_b_1, :a_b_1_a, :a_b_2, :a_b_2_a, :a_b_3, :a_b_3_a)

julia> values(fnt)
(1, (y = 2, z = 3, b = ((a = 1,), (a = 2,), (a = 3,))), 2, 3, ((a = 1,), (a = 2,), (a = 3,)), (a = 1,), 1, (a = 2,), 2, (a = 3,), 3)
```
"""
function flattened(nt::NamedTuple,
                   separator::Symbol = :_,
                   filter_leaves::Function = (pn,p) -> true,
                   process_leaves::Function = (pn,p) -> p,
                   stop_at_branch::Function = (x) -> false)
    k_all, v_all = [], []
    tup_chain = ()
    flattened!(k_all, v_all, nt, tup_chain, separator,
        filter_leaves, process_leaves, stop_at_branch)
    return (; zip(k_all, v_all)...)
end
