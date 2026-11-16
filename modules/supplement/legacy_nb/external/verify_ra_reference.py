"""Compare scalar author-recurrence transcription with vectorized recurrence.

This is a Python numerical reference check, not an R or MATLAB execution.
It writes deterministic MAT fixtures for NB_RA_SELFTEST in MATLAB.
"""
from pathlib import Path
import json
import numpy as np
from scipy.io import savemat


def recurrence(x, k, gamma, lam, vectorized):
    p,q,n=x.shape
    mean=x.mean(axis=2)
    y=x-mean[:,:,None]
    v=np.eye(q,k)
    previous=1.
    history=[]
    for iteration in range(1,101):
        cov=np.zeros((q,q))
        for i in range(n):
            z=y[:,:,i]
            residual=z-z@v@v.T
            if vectorized:
                d=np.linalg.norm(residual,axis=1)
                a=np.maximum(0,lam-d/gamma)/(np.linalg.norm(z,axis=1)*d+1e-4)
                cov+=z.T@(z*a[:,None])
            else:
                for j in range(p):
                    d=np.sqrt(np.sum(residual[j]**2))
                    a=max(0,lam-d/gamma)/(np.sqrt(np.sum(z[j]**2))*d+1e-4)
                    cov+=a*np.outer(z[j],z[j])
        vals,vecs=np.linalg.eigh((cov+cov.T)/2)
        v=vecs[:,np.argsort(vals)[::-1][:k]]
        f=sum(np.linalg.norm(y[:,:,i]-y[:,:,i]@v@v.T,'fro') for i in range(n))
        change=abs(f-previous)/f
        history.append([iteration,f,change])
        if change<=1e-4:
            break
        previous=f
    return v@v.T,np.asarray(history)


def main():
    root=Path(__file__).parent
    details=[]
    for index in range(1,4):
        p,q,n=5,6,8
        t=np.arange(1,p*q*n+1,dtype=float)
        # MATLAB column-major construction is part of the fixture contract.
        x=(np.sin(t*(.07+.013*index))+.3*np.cos(t*.11)).reshape((p,q,n),order='F')
        gamma,lam,k=4.+index,1.,2
        ps,hs=recurrence(x,k,gamma,lam,False)
        pv,hv=recurrence(x,k,gamma,lam,True)
        error=float(np.linalg.norm(ps-pv))
        assert error<1e-9 and hs.shape==hv.shape
        history_error=float(np.max(abs(hs-hv)))
        assert history_error<1e-8
        savemat(root/f'ra_fixture_{index}.mat',dict(X=x,k=k,gamma=gamma,lam=lam,
            expectedProjector=ps,expectedHistory=hs))
        details.append(dict(case=index,iterations=len(hs),projector_error=error,
            history_error=history_error))
    result=dict(reference='Python scalar transcription of author R recurrence',
        matlab_executed=False,R_executed=False,cases=details)
    (root/'RA_REFERENCE_VALIDATION.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
