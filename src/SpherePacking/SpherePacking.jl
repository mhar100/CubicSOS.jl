# These are the main tools useful in running tests for the sphere packing application

function check_bound_feasibility(rad, Fcoefs, Fpcoefs, F4bnd, num_xs, num_ys)
    # rad = the radius |x| > rad for which f(x) < 0
    # Other arguments assumed to be computed by populate_integrals!

    # Q1s, Q2s, for each interval we have a polynomial p which is written in terms of these matrices
    # X1s, X2s, the matrices defining the interpolants of \hat{f}(y) on each y interval
    # deltas = the "clearance" needed for the interpolants of \hat{f}(y) (a bound on fourth derivatives)
    Q1s = []; Q2s = []; X1s = []; X2s = [];
    num_xintervals = num_xs - 1
    num_yintervals = num_ys - 1
    for idx = 1:num_xintervals
        push!(Q1s, Variable(2,2))
        push!(Q2s, Variable(2,2))
    end
    for idx = 1:num_yintervals
        push!(X1s, Variable(2,2))
        push!(X2s, Variable(2,2))
    end
    #delta = Variable(num_yintervals);
#     constraints = [Q1s[idx] ⪰ 0 for idx in 1:num_xintervals if xs[idx] >= rad];
#     constraints += [Q2s[idx] ⪰ 0 for idx in 1:num_xintervals if xs[idx] >= rad];
    constraints = [Q1s[idx][1,2] >= norm([(Q1s[idx][1,1] + Q1s[idx][2,2])/2;(Q1s[idx][1,1] - Q1s[idx][2,2])/2],2)
                    for idx in 1:num_xintervals if xs[idx] >= rad];
    constraints += [Q2s[idx][1,2] >= norm([(Q2s[idx][1,1] + Q2s[idx][2,2])/2;(Q2s[idx][1,1] - Q2s[idx][2,2])/2],2)
                    for idx in 1:num_xintervals if xs[idx] >= rad];
    # Need all Qs symmetric regardless
    constraints += [Q1s[idx][1,2] == Q1s[idx][2,1] for idx in 1:num_xintervals]
    constraints += [Q2s[idx][1,2] == Q2s[idx][2,1] for idx in 1:num_xintervals]
#     constraints += [X1s[idx] ⪰ 0 for idx in 1:num_yintervals];
#     constraints += [X2s[idx] ⪰ 0 for idx in 1:num_yintervals];
    constraints += [X1s[idx][1,2] == X1s[idx][2,1] for idx in 1:num_yintervals]
    constraints += [X2s[idx][1,2] == X2s[idx][2,1] for idx in 1:num_yintervals]
    constraints += [X1s[idx][1,2] >= norm([(X1s[idx][1,1] + X1s[idx][2,2])/2;(X1s[idx][1,1] - X1s[idx][2,2])/2],2)
                    for idx in 1:num_yintervals];
    constraints += [X2s[idx][1,2] >= norm([(X2s[idx][1,1] + X2s[idx][2,2])/2;(X2s[idx][1,1] - X2s[idx][2,2])/2],2)
                    for idx in 1:num_yintervals];
    # Now set p to interpolate the values of f. p_i is the polynomial on interval i
    # we need p_i(x_i) = p_{i+1}(x_i) and same for the derivative
    for xind = 2:num_xintervals
        xi = xs[xind]
        xip1 = xs[xind+1]
        xim1 = xs[xind-1]
        constraints += [Q1s[xind-1][1,1] == Q2s[xind][2,2]]
        # Compute d/dx[p_i(x) exp(-pi*x^2)] via product rule and cancelling gives just
        constraints += [((3 * Q1s[xind-1][1,1] - 2 * Q1s[xind-1][2,1] - Q2s[xind-1][1,1])/(xi - xim1) ==
                         (Q1s[xind][2,2] - 3 * Q2s[xind][2,2] + 2 * Q2s[xind][1,2])/(xip1 - xi))]
    end

    # Write out the coefficients of p in the Lagrange basis
    C = Variable(num_xintervals, 4)
    for intnum = 1:num_xintervals
        constraints += [C[intnum, 1] == -Q1s[intnum][1,1]]
        constraints += [C[intnum, 2] == -(-2 * Q1s[intnum][1,2] - Q2s[intnum][1,1])]
        constraints += [C[intnum, 3] == -(2 * Q2s[intnum][1,2] + Q1s[intnum][2,2])]
        constraints += [C[intnum, 4] == Q2s[intnum][2,2]]
    end
    # We need to use -p to ensure this is less than 0.

    # Next, bound the fourth derivative of the interpolant of the fourier transform
    absC = Variable(size(C))
    constraints += [absC >= -C, absC >= C]

    ygap = ys[2] - ys[1] # TODO: More general?
    #ygap = 0
    # This used to be...
#     for intnum = 1:num_yintervals
#         ygap = ys[intnum+1] - ys[intnum]
#         constraints += [delta[intnum] >= ygap^4 / 384 * sum(absCF4bnd)]
#     end

    # Finally, this polynomial must be nonnegative
    # Constrain the interpolating polynomial to equal these values above
    for yintnum = 1:num_yintervals
        # Take a look at polynomial yintnum
        constraints += [sum(Fcoefs[yintnum, :, :] .* C) - ygap^4 / 384 * sum(absC .* F4bnd) >= X2s[yintnum][2,2]] #left hand endpoint
        constraints += [sum(Fcoefs[yintnum+1, :, :] .* C) - ygap^4 / 384 * sum(absC .* F4bnd) >= X1s[yintnum][1,1]]
        constraints += [sum(Fpcoefs[yintnum, :, :] .* C) * (ys[yintnum+1]-ys[yintnum]) == (X1s[yintnum][2,2] - 3 * X2s[yintnum][2,2] + 2 * X2s[yintnum][1,2])]
        constraints += [sum(Fpcoefs[yintnum+1, :, :] .* C) * (ys[yintnum+1]-ys[yintnum]) == (3 * X1s[yintnum][1,1] - 2 * X1s[yintnum][2,1] - X2s[yintnum][1,1])]
    end

    # We include the constraint \hat{f}(0) == f(0) > 0 noting that xs[1] == ys[1] == 0
    constraints += [sum(Fcoefs[1, :, :] .* C) == 1];
    constraints += [Q2s[1][2,2] == 1];

    problem = minimize(sum(absC), constraints)
    #solve!(problem, () -> SCS.Optimizer()) ### weird results are likely due to SCS inaccuracies
    opt = () -> Mosek.Optimizer(MSK_IPAR_INTPNT_SOLVE_FORM=MSK_SOLVE_DUAL,
                                MSK_IPAR_PRESOLVE_USE = 0,
                                MSK_DPAR_INTPNT_CO_TOL_PFEAS = 1e-6)
    solve!(problem, opt)
    @show problem.status
    @show MOI.get(problem.model, MOI.PrimalStatus())
   return Q1s, Q2s, X1s, X2s
end