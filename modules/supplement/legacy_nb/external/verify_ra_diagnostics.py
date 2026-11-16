"""Training-weight guard reference checks; does not execute MATLAB or R.

Loads the existing V1 fixture MAT files without changing them. The added
zero-weight guard must not alter the healthy reference recurrence.
"""
from pathlib import Path
import json
import numpy as np
from scipy.io import loadmat


def run(x, k, gamma, lam, centered=True, limit=100):
    p, q, n = x.shape
    mu = x.mean(axis=2) if centered else np.zeros((p, q))
    y = x - mu[:, :, None]
    v = np.eye(q, k)
    previous = 1.0
    history, weights = [], []
    status = 'iteration_limit'
    for iteration in range(1, limit + 1):
        cov = np.zeros((q, q))
        nonzero = 0
        for i in range(n):
            z = y[:, :, i]
            residual = z - (z @ v) @ v.T
            d = np.linalg.norm(residual, axis=1)
            a = np.maximum(0, lam - d / gamma) / (np.linalg.norm(z, axis=1) * d + 1e-4)
            nonzero += int(np.sum(a > 0))
            cov += z.T @ (z * a[:, None])
        covnorm = float(np.linalg.norm(cov))
        weights.append(dict(iteration=iteration, row_nonzero_fraction=nonzero/(p*n),
                            covariance_frobenius=covnorm, covariance_rank=int(np.linalg.matrix_rank(cov))))
        if nonzero == 0 or covnorm == 0:
            status = 'zero_weight_degenerate'
            break
        vals, vecs = np.linalg.eigh((cov+cov.T)/2)
        v = vecs[:, np.argsort(vals)[::-1][:k]]
        f = sum(np.linalg.norm(y[:, :, i] - (y[:, :, i] @ v) @ v.T) for i in range(n))
        if f == 0:
            status = 'zero_residual_degenerate'
            break
        change = abs(f-previous)/f
        history.append([iteration, f, change])
        if change <= 1e-4:
            status = 'relative_residual_stable'
            break
        previous = f
    return v, np.array(history), weights, status


def main():
    root = Path(__file__).parent
    cases = []
    for index in range(1, 4):
        f = loadmat(root/f'ra_fixture_{index}.mat', squeeze_me=True)
        v, h, trace, status = run(f['X'], int(f['k']), float(f['gamma']), float(f['lam']))
        pe = float(np.linalg.norm(v@v.T-f['expectedProjector']))
        he = float(np.max(np.abs(h-f['expectedHistory'])))
        assert pe < 1e-8 and he < 1e-7 and status != 'zero_weight_degenerate'
        cases.append(dict(case=index, projector_error=pe, history_error=he,
                          minimum_nonzero_fraction=min(t['row_nonzero_fraction'] for t in trace)))
    a = np.array([[0, 2, 3, 4], [0, 3, 4, 5], [0, 4, 5, 6]], dtype=float)
    x = np.stack([a, -a], axis=2)
    failed, _, trace, status = run(x, 1, 1, 1e-9, centered=False, limit=3)
    assert status == 'zero_weight_degenerate' and np.array_equal(failed, np.eye(4, 1))
    assert trace[0]['row_nonzero_fraction'] == 0 and trace[0]['covariance_rank'] == 0
    _, _, trace, status = run(x, 1, 1, 20, centered=False, limit=3)
    assert status != 'zero_weight_degenerate' and all(t['covariance_frobenius'] > 0 for t in trace)
    result = dict(matlab_executed=False, R_executed=False, healthy_fixture_parity=cases,
                  all_zero_control_labelled=True, all_zero_previous_basis_preserved=True,
                  positive_weight_control_healthy=True, scientific_fits_executed=False)
    (root/'RA_DIAGNOSTIC_VALIDATION.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
