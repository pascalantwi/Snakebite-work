# Preliminary single-lag screen of climate anomalies (hypothesis-generating; see REVIEW_DRAFT.md section 6.4).
# Usage: python3 analysis/prelim_lag_screen.py data_snake.csv
import sys, gc, numpy as np, pandas as pd, statsmodels.api as sm, patsy, warnings
warnings.filterwarnings('ignore')
d=pd.read_csv(sys.argv[1]).sort_values(['district','year','month']).reset_index(drop=True)
d=d.rename(columns={'Relative Humidity':'RH','Maximum Temperature':'Tmax','Minimum Temperature':'Tmin'})
north=['Northern','Upper East','Upper West','Savannah','North East']
d['zone']=np.where(d.region.isin(north),'north','south')
d['zm']=d.zone+'_'+d.month.astype(str)
V=['Rainfall','RH','T2M','Tmax','Tmin','ndvi']
for v in V:
    a=d[v]-d.groupby(['district','month'])[v].transform('mean'); d[v+'_a']=a/a.std()
    for L in range(7): d[f'{v}_a{L}']=d.groupby('district')[v+'_a'].shift(L)
sub=d.dropna(subset=['Rainfall_a6']).reset_index(drop=True)
sub=sub[sub.groupby('district').cases.transform('sum')>0].reset_index(drop=True)
print('dropped all-zero districts; n districts',sub.district.nunique())
def fit(s, extra, fam, zcol):
    X=patsy.dmatrix(f'C(district) + C({zcol}) + C(year)',s,return_type='matrix')
    X=np.asarray(X)
    if extra is not None: X=np.column_stack([X,s[extra].values])
    m=sm.GLM(s.cases.values,X,family=fam,offset=np.log(s.population.values)).fit()
    return m
m0=fit(sub,None,sm.families.Poisson(),'zm'); mu=m0.mu
alpha=((sub.cases-mu)**2-mu).sum()/(mu**2).sum(); print('NB alpha (moments)',round(alpha,3)); del m0; gc.collect()
fam=sm.families.NegativeBinomial(alpha=alpha)
mb=fit(sub,None,fam,'zm'); sub['eta0']=np.log(mb.mu); del mb; gc.collect()
def fit(s, extra, fam, zcol):
    X=sm.add_constant(s[[extra]].values)
    return sm.GLM(s.cases.values,X,family=fam,offset=s.eta0.values).fit()
for zone in ['all','north','south']:
    s=sub if zone=='all' else sub[sub.zone==zone].reset_index(drop=True)
    zcol=None
    print(f'\n== {zone} (n={len(s)}): RR per 1 SD anomaly (95% CI), lags 0..6',flush=True)
    for v in V:
        out=[]
        for L in range(7):
            m=fit(s,f'{v}_a{L}',fam,zcol); c=m.params[-1]; se=m.bse[-1]
            star='*' if abs(c/se)>1.96 else ' '
            out.append(f'{np.exp(c):.3f}[{np.exp(c-1.96*se):.2f},{np.exp(c+1.96*se):.2f}]{star}')
            del m; gc.collect()
        print(f'{v:9s}',' '.join(out),flush=True)
print('\nanomaly correlations (lag0)'); print(sub[[v+'_a0' for v in V]].corr().round(2))
print('raw correlations'); print(sub[V].corr().round(2))
