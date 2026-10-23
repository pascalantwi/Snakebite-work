# Does lagged local climate explain snakebite seasonality? Compares deviance of zone x month terms vs
# own lagged climate (lags 0-3, quadratic) vs placebo climate taken from a random district in the other
# rainfall regime (100 permutations). Poisson GLM, district rate + log population offset, year effects.
# Screening analysis for MANUSCRIPT_DRAFT.md section 2.4.5; final analysis uses NB GLMM + DLNM in R.
# Usage: python3 analysis/seasonality_climate_placebo.py data_snake.csv
import sys, numpy as np, pandas as pd, statsmodels.api as sm, warnings
warnings.filterwarnings('ignore'); rng=np.random.default_rng(1)
d=pd.read_csv(sys.argv[1]).sort_values(['district','year','month']).reset_index(drop=True)
d=d.rename(columns={'Relative Humidity':'RH','Maximum Temperature':'Tmax','Minimum Temperature':'Tmin'})
north=['Northern','Upper East','Upper West','Savannah','North East']
d['zone']=np.where(d.region.isin(north),'north','south')
d=d[d.groupby('district').cases.transform('sum')>0].reset_index(drop=True)
V=['Rainfall','RH','Tmin','Tmax','ndvi']; L=3
def lagmat(df,tag):
    cols=[]
    for v in V:
        for l in range(L+1):
            x=df.groupby('district')[v].shift(l); z=(x-d[v].mean())/d[v].std()
            df[f'{tag}{v}{l}']=z; df[f'{tag}{v}{l}_2']=z**2; cols+= [f'{tag}{v}{l}',f'{tag}{v}{l}_2']
    return cols
own=lagmat(d,'o_')
# placebo: give each district the climate series of a random district from the OTHER zone
dist=d.district.unique(); zone=d.groupby('district').zone.first()
full=d.groupby('district').size(); full=set(full[full==full.max()].index)
other={z:[k for k in zone[zone!=z].index if k in full] for z in ['north','south']}
mp={k:rng.choice(other[zone[k]]) for k in dist}
clim=d.set_index(['district','year','month'])[V]
pl=d[['district','year','month']].copy(); pl['src']=pl.district.map(mp)
P=clim.reindex(pd.MultiIndex.from_frame(pl[['src','year','month']])).reset_index(drop=True)
dp=d[['district','year','month','cases','population','zone','region']].copy()
for v in V: dp[v]=P[v].values
plac=lagmat(dp,'p_')
for c in plac: d[c]=dp[c].values
mask=d[own+plac].notna().all(axis=1)
s=d[mask].reset_index(drop=True)
# district fixed effects via offset (district rate), year dummies
rate=s.groupby('district').cases.transform('sum')/s.groupby('district').population.transform('sum')
off=np.log(s.population*rate)
Y=pd.get_dummies(s.year,prefix='y',drop_first=True).astype(float)
ZM=pd.get_dummies(s.zone+'_'+s.month.astype(str),drop_first=True).astype(float)
def dev(X):
    X=sm.add_constant(X.astype(float)); m=sm.GLM(s.cases,X,family=sm.families.Poisson(),offset=off).fit()
    return m.deviance, m.df_model
A=dev(Y); B=dev(pd.concat([Y,ZM],axis=1)); C=dev(pd.concat([Y,s[own]],axis=1))
D=dev(pd.concat([Y,ZM,s[own]],axis=1)); Pc=dev(pd.concat([Y,s[plac]],axis=1))
print('n',len(s))
for k,v in [('A district+year',A),('B +zone x month',B),('C +own lagged climate (no month terms)',C),('D +month +own climate',D),('P +PLACEBO climate (other-zone district)',Pc)]:
    print(f'{k:45s} deviance {v[0]:9.0f}  df {v[1]:.0f}')
seas=A[0]-B[0]
print(f'\nSeasonal deviance (A-B): {seas:.0f}')
print(f'Share of seasonal signal reproduced by own lagged climate (A-C)/(A-B): {(A[0]-C[0])/seas:.2f}')
print(f'Share reproduced by placebo climate (A-P)/(A-B): {(A[0]-Pc[0])/seas:.2f}')
print(f'Extra explained by climate beyond month terms (B-D): {B[0]-D[0]:.0f} on {D[1]-B[1]:.0f} df')
print(f'Extra explained by month terms beyond climate (C-D): {C[0]-D[0]:.0f} on {D[1]-C[1]:.0f} df')

disp=D[0]/(len(s)-D[1]-1); print('Pearson-ish dispersion (dev/df) of model D:',round(disp,2))
print('Own vs placebo, same df: scaled deviance gap',round((Pc[0]-C[0])/disp,1))
print('Own climate (C) vs month terms (B): scaled deviance gain',round((B[0]-C[0])/disp,1),'for',C[1]-B[1],'extra df')
# permutation distribution of placebo deviance
res=[]
base=d[['district','year','month','cases','population','zone','region']]
for it in range(100):
    mp={k:rng.choice(other[zone[k]]) for k in dist}
    pl=base[['district','year','month']].copy(); pl['src']=pl.district.map(mp)
    P=clim.reindex(pd.MultiIndex.from_frame(pl[['src','year','month']])).reset_index(drop=True)
    dp=base.copy()
    for v in V: dp[v]=P[v].values
    cols=lagmat(dp,'q_')
    q=dp.loc[mask.values].reset_index(drop=True)
    if q[cols].isna().any().any(): print('nan'); continue
    res.append(dev(pd.concat([Y,q[cols]],axis=1))[0])
res=np.array(res)
print('placebo deviance over 100 permutations: min',res.min().round(0),'median',np.median(res).round(0),'| own climate',round(C[0]))
print('permutation p-value (placebo <= own):',(np.sum(res<=C[0])+1)/(len(res)+1))
