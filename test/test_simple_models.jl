using Test
using StaticArrays
using VariableTemplates

@testset "Simple models" begin
    abstract type Model end
    struct SGSModel <: Model end
    struct MoistureModel <: Model
        sgs
    end
    struct AtmosModel <: Model
        moisture
    end

    function vars_state(m::SGSModel, FT)
        @vars begin
            x::FT
        end
    end
    function vars_state(m::MoistureModel, FT)
        @vars begin
            x::FT
            sgs::vars_state(m.sgs, FT)
        end
    end
    function vars_state(m::AtmosModel, FT)
        @vars begin
            ρ::FT
            ρu::SVector{3, FT}
            ρe::FT
            moisture::vars_state(m.moisture, FT)
        end
    end

    FT = Float32;

    # AtmosModel
    sgs = SGSModel()
    st = vars_state(sgs, FT)
    nt = concretize(st)
    @test nt.x.type == Val(FT)
    @test nt.x.gid == Val(1)

    m = MoistureModel(sgs)
    st = vars_state(m, FT)
    nt = concretize(st)
    @test nt.x.type == Val(FT)
    @test nt.x.gid == Val(1)
    @test nt.sgs.x.type == Val(FT)
    @test nt.sgs.x.gid == Val(2)

    atmos = AtmosModel(m)
    st = vars_state(atmos, FT)
    nt = concretize(st)
    @test nt.ρ.type == Val(FT)
    @test nt.ρ.gid == Val(1)
    @test nt.ρu.type == Val(SVector{3, FT})
    @test nt.ρu.gid == Val(2)
    @test nt.ρe.type == Val(FT)
    @test nt.ρe.gid == Val(5)
    @test nt.moisture.x.type == Val(FT)
    @test nt.moisture.x.gid == Val(6)
    @test nt.moisture.sgs.x.type == Val(FT)
    @test nt.moisture.sgs.x.gid == Val(7)

    vs = varsize(nt)
    a_global = collect(1:vs)
    v = Vars{nt}(a_global)
    @test VariableTemplates.get_tup_chain(v) == ()
    ρ = v.ρ
    @test ρ == 1
    ρu = v.ρu
    @test ρu == [2,3,4]
    ρe = v.ρe
    @test ρe == 5
    moisture = v.moisture
    @test VariableTemplates.get_tup_chain(moisture) == (:moisture,)
    sgs = moisture.sgs
    @test VariableTemplates.get_tup_chain(sgs) == (:moisture, :sgs)
    x = sgs.x
    @test x == 7
end
