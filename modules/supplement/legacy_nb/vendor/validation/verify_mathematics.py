"""Independent NumPy checks; NOT MATLAB execution or manuscript experiments."""
from pathlib import Path
import hashlib
import itertools
import json
import re
import sys

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
rng = np.random.default_rng(20261004)


def qf(a):
    q, r = np.linalg.qr(a, mode="reduced")
    s = np.sign(np.diag(r))
    s[s == 0] = 1
    return q * s


def residual(x, u, v):
    return np.stack([xi - u @ (u.T @ xi @ v) @ v.T for xi in x])


def rho(e, name, tau):
    if name == "tukey":
        inside = np.abs(e) <= tau
        out = np.full_like(e, tau * tau / 6)
        z = (e[inside] / tau) ** 2
        out[inside] = e[inside] ** 2 * (.5 - .5*z + z*z/6)
        return out
    if name == "huber":
        a = np.abs(e)
        return np.where(a <= tau, .5*e*e, tau*a-.5*tau*tau)
    if name == "welsch":
        return -(tau*tau/2)*np.expm1(-(e/tau)**2)
    return .5*e*e


def element_weights(e, name, tau):
    if name == "tukey":
        return np.where(np.abs(e) <= tau, (1-(e/tau)**2)**2, 0)
    if name == "huber":
        return np.minimum(1, tau/np.maximum(np.abs(e), 1e-300))
    if name == "welsch":
        return np.exp(-(e/tau)**2)
    return np.ones_like(e)


def evaluate(x, u, v, w, a, name, tau, guard=False, gradient=True):
    e = residual(x, u, v)
    q = np.sum(w*e*e)
    f = np.sum(a[:, None, None]*rho(e, "l2" if guard else name, tau))
    gu, gv = np.zeros_like(u), np.zeros_like(v)
    if gradient:
        for xi, ei, wi in zip(x, e, w):
            h = wi*ei
            gu -= 2*((h@v)@(v.T@(xi.T@u))+(xi@v)@(v.T@(h.T@u)))
            gv -= 2*((h.T@u)@(u.T@(xi@v))+(xi.T@u)@(u.T@(h@v)))
        gu -= u@(u.T@gu)
        gv -= v@(v.T@gv)
    return float(q), float(f), gu, gv


gradient_errors, invariance_errors = [], []
for _ in range(50):
    x = rng.normal(size=(4, 7, 6))
    u, v = qf(rng.normal(size=(7, 3))), qf(rng.normal(size=(6, 2)))
    a = rng.uniform(.6, 1, 4)
    w = rng.uniform(0, 1, x.shape)*a[:, None, None]
    q, f, gu, gv = evaluate(x, u, v, w, a, "tukey", 2)
    du, dv = rng.normal(size=u.shape), rng.normal(size=v.shape)
    du -= u@(u.T@du)
    dv -= v@(v.T@dv)
    eps = 1e-6
    qp = evaluate(x, u+eps*du, v+eps*dv, w, a, "tukey", 2, gradient=False)[0]
    qm = evaluate(x, u-eps*du, v-eps*dv, w, a, "tukey", 2, gradient=False)[0]
    fd = (qp-qm)/(2*eps)
    an = np.sum(gu*du)+np.sum(gv*dv)
    gradient_errors.append(abs(fd-an)/max(1, abs(fd), abs(an)))
    ou, ov = qf(rng.normal(size=(3, 3))), qf(rng.normal(size=(2, 2)))
    qr = evaluate(x, u@ou, v@ov, w, a, "tukey", 2, gradient=False)[0]
    invariance_errors.append(abs(qr-q)/max(1, abs(q)))
assert max(gradient_errors) < 2e-6
assert max(invariance_errors) < 1e-12

majorizer_count, majorizer_violations, max_guard_error = 0, 0, 0
gradient_accepted = 0
for name in ["tukey", "huber", "welsch", "l2"]:
    for guard in [False, True]:
        x = rng.normal(size=(5, 8, 6))
        u, v = qf(rng.normal(size=(8, 3))), qf(rng.normal(size=(6, 2)))
        a = rng.uniform(.6, 1, 5)
        e = residual(x, u, v)
        we = np.ones_like(e) if guard else element_weights(e, name, 2)
        w = we*a[:, None, None]
        q0, f0, gu, gv = evaluate(x, u, v, w, a, name, 2, guard)
        if guard:
            max_guard_error = max(max_guard_error, abs(f0-.5*q0))
        for _ in range(30):
            ut, vt = qf(rng.normal(size=u.shape)), qf(rng.normal(size=v.shape))
            qt, ft, _, _ = evaluate(x, ut, vt, w, a, name, 2, guard, False)
            upper = f0+.5*(qt-q0)
            majorizer_count += 1
            majorizer_violations += int(ft > upper+1e-8*(1+abs(f0)+abs(upper)))
        gn = np.sqrt(np.sum(gu*gu)+np.sum(gv*gv))
        beta = min(1, 1/max(1, gn))
        ok = False
        for _ in range(41):
            ut, vt = qf(u-beta*gu), qf(v-beta*gv)
            qt, ft, _, _ = evaluate(x, ut, vt, w, a, name, 2, guard, False)
            if qt <= q0-1e-4*beta*gn*gn+1e-10*(1+abs(q0)):
                ok = True
                assert qt <= q0+1e-10*(1+abs(q0))
                break
            beta *= .5
        assert ok
        gradient_accepted += 1
assert majorizer_violations == 0
assert max_guard_error < 1e-12

# Guarded, feasible sample coefficients within .2**.35 <= a <= 1.
x = np.stack([np.diag([3., 0]), np.diag([0, 3.5])])
a = np.array([1., .6])
assert a.min() >= .2**.35
w = np.ones_like(x)*a[:, None, None]
u0, u1 = np.array([[0.], [1.]]), np.array([[1.], [0.]])
qb, fb, _, _ = evaluate(x, u0, u0, w, a, "tukey", 100, True)
qt, ft, _, _ = evaluate(x, u1, u1, w, a, "tukey", 100, True)
lb, lt = rho(residual(x, u0, u0), "tukey", 100).sum(), rho(residual(x, u1, u1), "tukey", 100).sum()
assert qt < qb and lt > lb and abs(ft-.5*qt) < 1e-12

# The engineering MATLAB selftest's deliberately unsuccessful one-trial search.
x = np.array([np.diag([10., 0])])
u = np.array([[np.cos(.02)], [np.sin(.02)]])
q0, _, gu, gv = evaluate(x, u, u, np.ones_like(x), np.ones(1), "l2", np.nan)
gn = np.sqrt(np.sum(gu*gu)+np.sum(gv*gv))
beta = min(1, 1/max(1, gn))
qtrial = evaluate(x, qf(u-beta*gu), qf(u-beta*gv), np.ones_like(x), np.ones(1), "l2", np.nan, gradient=False)[0]
assert gn/max(1, q0) > 1e-6
assert qtrial > q0-1e-4*beta*gn*gn+1e-10*(1+abs(q0))

# Exact sign flip sanity and undefined rejection ratios.
d = np.ones(4)
null = [abs(np.mean(np.array(s)*d)) for s in itertools.product([-1, 1], repeat=4)]
assert np.mean(np.array(null) >= abs(d.mean())-1e-14) == .125
e = np.array([0., .5, 1., 1+np.spacing(1.), 2.])
we = element_weights(e, "tukey", 1)
m = np.array([False, False, False, True, True])
z = we == 0
assert z.sum() == 3 and np.mean(np.abs(e)>1) == .4
assert np.sum(z&m)/m.sum() == 1 and abs(np.sum(z&~m)/(~m).sum()-1/3) < 1e-12

# Source snapshot verification and MATLAB lexical/block checks (NOT compilation).
provenance = json.loads((ROOT/"FROZEN_SOURCE_PROVENANCE.json").read_text())
for item in provenance:
    assert hashlib.sha256((ROOT/item["bundled"]).read_bytes()).hexdigest() == item["sha256"]

# FIX1 regression: audit alg fields reachable from the frozen real training path.
# This detects the omitted severityMemoryMode without claiming MATLAB execution.
frozen_source = (ROOT/'frozen'/'SU_FROZEN.m').read_text(encoding='utf-8')
function_pattern = re.compile(r'^function\s+(?:(?:\[[^\]]*\]|\w+)\s*=\s*)?(\w+)\s*\(', re.M)
matches = list(function_pattern.finditer(frozen_source))
local_functions = {
    match.group(1): frozen_source[match.start():matches[i+1].start() if i+1 < len(matches) else len(frozen_source)]
    for i, match in enumerate(matches)
}
pending, reachable = ['train_robust_bpca_irls_v6'], set()
while pending:
    name = pending.pop()
    if name in reachable:
        continue
    reachable.add(name)
    body = re.sub(r'%[^\n]*', '', local_functions[name])
    calls = set(re.findall(r'\b(\w+)\s*\(', body))
    pending.extend((calls & local_functions.keys()) - reachable)
referenced_fields = set()
for name in reachable:
    body = re.sub(r'%[^\n]*', '', local_functions[name])
    referenced_fields.update(re.findall(r'\balg\.([A-Za-z]\w*)', body))
alg_source = (ROOT/'P0_ALG.m').read_text(encoding='utf-8')
selftest_source = (ROOT/'P0_SELFTEST.m').read_text(encoding='utf-8')
replay_start = selftest_source.index('% Frozen real solver replay on engineering-only arrays')
replay_end = selftest_source.index('old=SU_FROZEN(', replay_start)
replay_setup = selftest_source[replay_start:replay_end]
provided_fields = set(re.findall(r'\bA\.([A-Za-z]\w*)\s*=', alg_source))
provided_fields.update(re.findall(r'\bAr\.([A-Za-z]\w*)\s*=', replay_setup))
guarded_optional_fields = {'sampleStrongDownweightThreshold'}
missing_fields = referenced_fields - provided_fields - guarded_optional_fields
assert not missing_fields, f'Frozen real replay configuration missing fields: {sorted(missing_fields)}'
expected_mode = re.search(r"cfg\.alg\.severityMemoryMode\s*=\s*'([^']+)'", frozen_source).group(1)
actual_mode = re.search(r"Ar\.severityMemoryMode\s*=\s*'([^']+)'", replay_setup).group(1)
assert actual_mode == expected_mode == 'max'
# A negative control reproduces the reported omission; the audit must detect it.
removed_mode = re.sub(r"Ar\.severityMemoryMode\s*=\s*'[^']+'\s*;", '', replay_setup)
negative_fields = set(re.findall(r'\bA\.([A-Za-z]\w*)\s*=', alg_source))
negative_fields.update(re.findall(r'\bAr\.([A-Za-z]\w*)\s*=', removed_mode))
assert referenced_fields - negative_fields - guarded_optional_fields == {'severityMemoryMode'}

sys.path.append('/usr/lib/python3/dist-packages')
from pygments.lexers import MatlabLexer
from pygments.token import Token
issues = []
functions = set()
files = sorted(ROOT.glob('*.m'))
for file in files:
    source = file.read_text(encoding='utf-8')
    match = re.search(r'^function\s+(?:(?:\[[^\]]*\]|\w+)\s*=\s*)?(\w+)\s*\(', source, re.M)
    assert match and match.group(1) == file.stem, f'Main function/filename mismatch: {file.name}'
    functions.add(file.stem)
    stack = []
    paren = bracket = brace = 0
    line = 1
    for typ, value in MatlabLexer().get_tokens(source):
        if typ in Token.Error:
            issues.append(f'{file.name}:{line}: lexer error {value!r}')
        if typ in Token.Keyword and not (paren or bracket or brace):
            word = value.strip()
            if word in {'function', 'if', 'for', 'while', 'switch', 'try', 'parfor'}:
                stack.append((word, line))
            elif word == 'end':
                if stack:
                    stack.pop()
                else:
                    issues.append(f'{file.name}:{line}: unexpected block end')
        if not (typ in Token.Literal.String or typ in Token.Comment):
            for ch in value:
                if ch == '(': paren += 1
                if ch == ')': paren -= 1
                if ch == '[': bracket += 1
                if ch == ']': bracket -= 1
                if ch == '{': brace += 1
                if ch == '}': brace -= 1
        line += value.count('\n')
    if stack or paren or bracket or brace:
        issues.append(f'{file.name}: unmatched blocks/delimiters {stack}, {paren}, {bracket}, {brace}')
for file in files:
    for name in re.findall(r'\b(P0_[A-Z0-9_]+)\s*\(', file.read_text()):
        if name not in functions:
            issues.append(f'{file.name}: unresolved local package function {name}')
assert not issues, '\n'.join(issues)

report = {
    'EngineeringOnly': True,
    'MATLABExecuted': False,
    'OctaveExecuted': False,
    'ScientificFitsExecuted': False,
    'MathematicalChecksPass': True,
    'MaximumScaledGradientError50Checks': max(gradient_errors),
    'MaximumBasisInvariantQError50Checks': max(invariance_errors),
    'MajorizerTrials': majorizer_count,
    'MajorizerViolations': majorizer_violations,
    'MaximumGuardEqualityError': max_guard_error,
    'GradientBacktrackingChecks': gradient_accepted,
    'GuardCounterexample': {'QBefore': qb, 'QAfter': qt, 'LBefore': float(lb), 'LAfter': float(lt)},
    'FailedSearchTestRetainsFailure': True,
    'ExactSignFlipCheck': True,
    'FrozenSnapshotHashesVerified': len(provenance),
    'RealReplayConfigurationAuditFunctions': len(reachable),
    'RealReplayRequiredAlgFieldsCovered': len(referenced_fields - guarded_optional_fields),
    'RealReplayMissingAlgFields': sorted(missing_fields),
    'RealReplayMemoryModeMatchesFrozen': actual_mode == expected_mode,
    'RealReplayMissingMemoryModeNegativeControlPass': True,
    'MATLABLexicalBlockFilesChecked': len(files),
    'MATLABLexicalBlockIssues': issues,
    'CompilationGuarantee': False,
}
(ROOT/'validation'/'LOCAL_VALIDATION_REPORT.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
