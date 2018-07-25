abstract type AbstractAlgorithm end

# Solution of the full optimization, not an AbstractSolution
struct SolutionSummary
    status
    objval
    sol
    attrs
end

# Path represents a scenario along with a vector of AbstractSolution that
# corresponds to solutions for each node visited by the scenario
struct Path{T<:AbstractTransition, SolT<:AbstractSolution}
    scenario::Vector{T}
    sol_scenario::Vector{SolT}
end

"""
    optimize!(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
              stopcrit::AbstractStoppingCriterion, verbose=0)

Run the algorithm `algo` on the stochastic program `sp` until the termination
criterion `stopcrit` requires stopping with verbose level `verbose`.
"""
function optimize!(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
                   stopcrit::AbstractStoppingCriterion=IterLimit(), verbose=0)
    # Default implementation, define a specific method for algorithms for which
    # this default is not appropriate
    info = Info()
    while !stop(stopcrit, info)
        @timeit info.timer "iteration $(niterations(info)+1)" begin
            result = iterate!(sp, algo, info.timer, verbose)
        end
        push!(info.results, result)
        if verbose >= 3
            print_iteration_summary(info)
        end
        if getstatus(result.paths[1].sol_scenario[1]) != :Infeasible
            break
        end
    end
    if verbose >= 2
        print_termination_summary(info)
    end
    info
end

"""
    iterate!(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
             to::TimerOutput, verbose)

Run one iteration of the algorithm `algo` on the stochastic program `sp` with
verbose level `verbose`. Return the solution of the master state and the stats.
"""
function iterate!(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
                  to::TimerOutput, verbose)
    # Default implementation, define a specific method for algorithms for which
    # this default is not appropriate
    result = Result()

    forward_pass!(sp, algo, to, result, verbose)
    backward_pass!(sp, algo, to, result, verbose)

    process!(sp, algo, to, result, verbose)

    # Uses result so that its are used for upperbound, σ_UB and npaths
    result
end

"""
    forward_pass(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
                 to::TimerOutput, result::Result, verbose)

Run the forward pass of algorithm `algo` on the stochastic program `sp` with
verbose level `verbose`. Update structure `result` with generated forward paths
and information of the iteration.
"""
function forward_pass!(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
                       to::TimerOutput, result::Result, verbose)
    # Default implementation, define a specific method for algorithms for which
    # this default is not appropriate
    scenarios = sample_scenarios(sp, algo, to, verbose)

    paths = Vector{Path}(length(scenarios)) #Consider that sample_scenarios
                                            #always return at least one scenario

    i = 1
    for s in scenarios
        path = simulate_scenario(sp, algo, s, to, verbose)
        paths[i] = path
        i += 1
    end

    # Result update
    z_UB, σ = compute_bounds(algo,paths)
    result.paths = paths
    result.upperbound = z_UB
    result.σ_UB = σ
end

"""
    backward_pass!(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
                   to::TimerOutput, result::Result, verbose)

Run the backward pass of algorithm `algo` on the stochastic program `sp` with
verbose level `verbose` and use paths and information of iteration in structure
`result`.
"""
function backward_pass! end

"""
    simulate_scenario(sp::AbstractStochasticProgram,
                      scenario::Vector{<:AbstractTransition},
                      to::TimerOutput, verbose)

Simulate a scenario `scenario` on the stochastic program `sp` with verbose level
`verbose`.
"""
function simulate_scenario end

"""
    sample_scenarios(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
                     s::Vector{<:AbstractTransition}, to::TimerOutput, verbose)

Return a vector of scenarios where each scenario is a vector of
AbstractTransition from the stochastic program `sp`sampled according to
algorithm `algo` with verbose level `verbose`.
"""
function sample_scenarios end

"""
    compute_bounds(algo::AbstractAlgorithm, paths::Vector{Path}, verbose)

Return a tuple `(z_UB, σ)` where z_UB reprensets the upperbound computed by the
algorithm `algo` by using paths `paths` generated during the forward pass and σ
represents the standard deviation of this upper bound.
"""
function compute_bounds end

"""
    process(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
            to::TimerOutput, result::Result, verbose)

Function called at the end of function iterate! to update necessary elements
related with the implementation of the algorithm `algo` on the stochastic
program `sp` considering forward paths `paths`.
"""
function process!(sp::AbstractStochasticProgram, algo::AbstractAlgorithm,
                  to::TimerOutput, result::Result, verbose)
end
