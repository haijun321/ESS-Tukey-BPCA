"""Independent numerical checks of manuscript mathematics (not MATLAB execution).

This script uses NumPy and finite differences; it neither imports nor translates
the MATLAB solver.  Its pass result is not a MATLAB integration-test pass.
"""
from __future__ import annotations

import json
from pathlib import Path
import numpy as np


def orth(a):
    q, r = np.linalg.qr(a, mode="reduced")
    signs = np.sign(np.diag(r))
    signs[signs == 0] = 1
    return q * signs


def residual(x, u, v):
    return x - (u @ u.T) @ x @ (v @ v.T)


def weighted_q(x, u, v, w):
    return sum(float(np.sum(wi * residual(xi, u, v) ** 2))
               for xi, wi in zip(x, w))


def projected_gradient(x, u, v, w):
    # Differentiate through the two projectors, rather than through matrix scores.
    pu, pv = u @ u.T, v @ v.T
    gu, gv = np.zeros_like(u), np.zeros_like(v)
    for xi, wi in zip(x, w):
        h = wi * (xi - pu @ xi @ pv)
        gu -= 2 * (h @ pv @ xi.T + xi @ pv @ h.T) @ u
        gv -= 2 * (h.T @ pu @ xi + xi.T @ pu @ h) @ v
    return (np.eye(len(u)) - pu) @ gu, (np.eye(len(v)) - pv) @ gv


def tukey_rho(e, tau):
    z = np.minimum((e / tau) ** 2, 1.0)
    return tau * tau / 6.0 * (3 * z - 3 * z * z + z ** 3)


def main():
    rng = np.random.default_rng(20261115)
    max_gradient_error = 0.0
    max_majorizer_excess = 0.0
    for _ in range(40):
        x = rng.normal(size=(5, 8, 7))
        u, v = orth(rng.normal(size=(8, 3))), orth(rng.normal(size=(7, 2)))
        w = rng.uniform(size=x.shape)
        du = (np.eye(8) - u @ u.T) @ rng.normal(size=u.shape)
        dv = (np.eye(7) - v @ v.T) @ rng.normal(size=v.shape)
        gu, gv = projected_gradient(x, u, v, w)
        analytic = float(np.sum(gu * du) + np.sum(gv * dv))
        step = 1e-6
        fp = weighted_q(x, orth(u + step * du), orth(v + step * dv), w)
        fm = weighted_q(x, orth(u - step * du), orth(v - step * dv), w)
        fd = (fp - fm) / (2 * step)
        error = abs(fd - analytic) / max(1.0, abs(fd), abs(analytic))
        max_gradient_error = max(max_gradient_error, error)

        tau = 1.3
        anchor = residual(x, u, v)
        weights = np.maximum(0.0, 1.0 - (anchor / tau) ** 2) ** 2
        a = rng.uniform(0.2, 1.0, size=(len(x), 1, 1))
        uu, vv = orth(rng.normal(size=u.shape)), orth(rng.normal(size=v.shape))
        trial = residual(x, uu, vv)
        lhs = float(np.sum(a * tukey_rho(trial, tau)))
        rhs = float(np.sum(a * tukey_rho(anchor, tau))
                    + 0.5 * np.sum(a * weights * (trial ** 2 - anchor ** 2)))
        max_majorizer_excess = max(max_majorizer_excess, lhs - rhs)

    wa = np.r_[np.full(8, 0.001), 0.0, 0.0]
    wb = np.r_[np.ones(5), np.full(5, 1.0 / 3.0)]
    ess = lambda w: float(w.sum() ** 2 / np.dot(w, w) / len(w))
    assert abs(ess(wa) - 0.8) < 1e-12
    assert abs(ess(wb) - 0.8) < 1e-12
    assert max_gradient_error < 2e-6, max_gradient_error
    assert max_majorizer_excess < 1e-10, max_majorizer_excess
    report = {
        "pass": True,
        "scope": "independent_numpy_mathematics_only",
        "matlab_executed": False,
        "scientific_experiments_executed": False,
        "random_trials": 40,
        "maximum_relative_gradient_error": max_gradient_error,
        "maximum_majorizer_excess": max_majorizer_excess,
        "positive_equal_weights_with_zeros_ess": ess(wa),
        "equal_ess_different_zero_fraction": True,
    }
    out = Path(__file__).with_name("mathematics_check.json")
    out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
