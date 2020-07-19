export @vars

function process_vars!(syms, typs, expr)
    if expr isa LineNumberNode
        return
    elseif expr isa Expr && expr.head == :block
        for arg in expr.args
            process_vars!(syms, typs, arg)
        end
        return
    elseif expr.head == :(::)
        push!(syms, expr.args[1])
        push!(typs, expr.args[2])
        return
    else
        error("Invalid expression")
    end
end

macro vars(args...)
    syms = Any[]
    typs = Any[]
    for arg in args
        process_vars!(syms, typs, arg)
    end
    :(NamedTuple{$(tuple(syms...)), Tuple{$(esc.(typs)...)}})
end
