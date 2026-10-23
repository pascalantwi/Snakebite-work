# REVIEW DRAFT

## Lagged climate effects on snakebite incidence in Ghana: literature review, gap analysis and a proposed novel GLMM study

**Status:** working draft, 23 October 2026. Written for the author (P. Antwi) to develop into a manuscript.

**Dataset:** `data_snake.csv` in this repository. It covers 261 districts, 16 regions, January 2020 – November 2025, at district-month level: 18,485 rows and 60,515 cases.

> **How to use this draft**
> * Section 1 sets out the research question as the author framed it.
> * Sections 2–5 are the literature review.
> * Section 6 describes what the dataset already shows, including a preliminary screen of lagged effects.
> * Section 7 is the gap analysis.
> * Section 8 is the proposed novel study (objectives, hypotheses, model specification, R code skeleton, sensitivity analyses).
> * Section 9 lists threats to novelty that must be checked before submission.
> * Section 10 lists references.
>
> **Verification note:** this review was compiled from web-search abstracts and summaries. Full-text access to PubMed Central, medRxiv and Crossref was blocked from the environment used to write it. Every reference marked **[verify]** must be checked against the full text (exact numbers, lags, authors, volume and pages) before citing. Novelty claims are worded as "to our knowledge". Re-run a formal PubMed/Scopus/Web of Science search before submission (Section 9 gives a search string).

---

## 1. Research question as framed by the author

> Do rainfall, relative humidity and temperature in **previous months** affect the number of snakebite cases in the **current month** in Ghanaian districts? This is to be estimated with a **generalized linear mixed model (GLMM)** with a **population offset**, adding a methodological or substantive element that has **not been done before**.

The question has three parts:

1. **Exposure–lag structure.** Which climate variables matter, at which lags (0, 1, 2, … months), and is the effect linear?
2. **Hierarchical count model.** The outcome is a count per district-month, modelled as a rate per population (offset log population). It needs district (and region) random effects to absorb unmeasured, time-invariant heterogeneity: snake fauna, land use, health-facility access and reporting culture.
3. **Novel contribution.** Something that moves beyond "concurrent climate covariates in a spatio-temporal model". A nationwide Ghana analysis of that kind already exists as a 2026 preprint (Section 5.1).

---

## 2. Background and burden

* **Global burden.** A 2026 geostatistical update (Ediriweera, Kasturiratne et al., *PLoS Med* 23(8):e1005201) estimates at least 2.1 million envenomings per year, possibly up to about 7 million. Deaths are estimated at 274,000–513,000 per year after adjusting for under-reporting. Sub-Saharan Africa accounts for about 45% of envenomings and deaths [verify]. The earlier benchmark was Kasturiratne et al. 2008 (*PLoS Med* 5:e218): at least 421,000 envenomings and 20,000 deaths per year.
* **Policy.** WHO re-listed snakebite envenoming as a category A Neglected Tropical Disease in 2017. WHO's 2019 strategy aims to halve deaths and disabilities by 2030. The 2025 *TRSTMH* special issue ("Addressing the snakebite challenge – progress towards the 2030 roadmap") calls for research led from high-burden regions, especially sub-Saharan Africa.
* **Ghana.**
  * A press report of a KCCR-led analysis gives about 9,600 health-facility-reported snakebites per year. A review cites a hospital-visit rate of about 35 per 100,000 per year [verify].
  * **This dataset agrees with both figures:** about 10,500 cases per year in 2020–2024, a crude rate of 32.4 per 100,000 per year.
  * Regional DHIMS-2 analyses report:
    * about 24 per 100,000 in Volta/Oti (2014–2018, *Pan Afr Med J* 2021)
    * about 101 per 100,000 in Savannah Region (2018–2022, *J Interv Epidemiol Public Health* 2025)
    * an analysis of Volta 2018–2023 in *TRSTMH* 2025
  * DHIMS-2 captures only health-facility cases. Many victims go first, or only, to traditional healers. Facility data are therefore a lower bound and may be differentially incomplete across districts. That is an argument for district random effects.
  * **Main species:** the West African carpet or saw-scaled viper (*Echis ocellatus*) in the savanna; also *Bitis arietans*, *Naja* spp. and *Dendroaspis* spp. In a northern Ghana savanna community (Savelugu-Nanton), bites peaked in the rainy season and on farmland, most severe bites were from *E. ocellatus*, and the association with rainfall intensity was **hump-shaped** (Musah et al. 2019, *PLoS NTD* 13(8):e0007221 [verify]).

---

## 3. Why climate should act on snakebite with a delay: mechanisms

A lag hypothesis needs a mechanism. The literature supports at least four pathways, each with a different expected lag:

| Pathway | Mechanism | Expected lag | Supporting evidence |
|---|---|---|---|
| **A. Snake activity / thermal ecology** | Ectotherms are more active, forage and disperse more at favourable temperatures. Extreme heat suppresses surface activity. | 0–1 month | Costa Rica: +24% incidence per °C above average, temperature at lag 1 (Chaves et al. 2015). Brazil: temperature RR ≈ 1.23 per °C in the temperate zone but null in the equatorial zone (Vilhena Neto et al., SSRN preprint) |
| **B. Human exposure: agricultural calendar** | Rain onset triggers land clearing, planting and weeding. Barefoot work in fields; harvest later in the season. | 0–2 months after rainfall onset | Benin and wider West Africa: most bites occur in the rainy season during agricultural work (Benin review 2024). Northern Ghana: farmland, males aged 15–44 |
| **C. Habitat, vegetation and prey (bottom-up)** | Rain → vegetation (NDVI) → seed and insect pulse → rodent prey → snake foraging and recruitment | 1–4 months (vegetation and rodents); 6–18 months (population) | Sahel gerbils increase after rainfall up to 1 year earlier (2018). California: bites fall after drought at lag 6 months and rise after rainfall over the previous 18 months (Phillips et al. 2019). Costa Rica: rainfall at lag 11 months (negative cross-correlation) |
| **D. Displacement / refuge-seeking** | Flooding of burrows; humidity and moisture extremes push snakes into houses and compounds | 0 months | Sri Lanka: *low* humidity is associated with more bites (Ediriweera et al. 2018). Rondônia: humidity changes increased risk in all four cities. Israel: heatwaves (cited in climate systematic review) |

**Implication for modelling.** Different pathways act at different lags and may have *opposite signs*. For example, a wet month raises same-month exposure, while a long dry spell several months earlier depresses prey. A single-lag model or a fixed moving average cannot separate them. A distributed-lag model can.

---

## 4. Evidence review: climate and snakebite incidence

### 4.1 Systematic reviews

* **Collinson, Lamb, Cardoso, Diggle, Lalloo (*TRSTMH* 2025, doi:10.1093/trstmh/trae131).** This is a systematic review of variables used in spatial and temporal snakebite analyses (35 studies: 18 from Central/South America, 11 from Asia).
  * Temperature, humidity and tree cover were mostly *positively* associated with risk.
  * Drought was negatively associated.
  * Altitude was negative or mixed.
  * Agricultural variables were mostly positive; population density and urban residence mostly negative.
  * The review states that sub-Saharan Africa is under-represented.
  * It interprets negative temperature and humidity associations in some studies as snake activity falling when conditions go *beyond* the species' optimum. This supports **non-linear** exposure–response functions.
  * [verify: whether and how lags were reported; issue/pages differ between sources]
* **A climate-change and snakebite review (eight studies) [verify citation].** It reports a poleward shift of risk in the Americas and in Mozambique. Hurricanes and US droughts showed no association; heatwaves in Israel did. It also notes "almost no evidence" from high-burden South Asia and sub-Saharan Africa.

### 4.2 Time-series and panel studies with explicit climate terms

| Study | Setting, period | Unit | Model | Climate terms | Lags? | Key finding |
|---|---|---|---|---|---|---|
| Chaves, Chuang, Sasa, Gutiérrez 2015, *Sci Adv* 1:e1500249 | Costa Rica, 2005–2013 | Canton-month / national | Log-linear time series with SAR terms; cross-correlation | Temp, rainfall, ENSO | **Yes**, chosen by cross-correlation | +24% per °C (lag 1); rainfall lag 11 negative; both ENSO phases raise incidence; poverty |
| Ediriweera et al. 2018, *IJE* 47(6):2049 | Sri Lanka, national survey 2012–13 | National monthly | Log-linear with harmonics | RH, rainfall, temperature | Limited [verify] | Low RH → more bites; +31% projected burden under climate change |
| Bravo-Vega, Santos-Vega, Cordovez 2022, *PLoS NTD* 16(3):e0010270 | Colombia | Municipality groups by rainfall regime | Compartmental (mechanistic) models | Rainfall, temperature | Implicit via dynamics | Rainfall drives incidence **only where the dry season is marked**; temperature had no effect |
| Rondônia, Brazil, *Rev Soc Bras Med Trop* 2020 [verify authors] | 4 municipalities, 2007–2018 | Municipality-month | Bayesian time series (double Poisson, harmonics, AR) | Rainfall, LST, humidity | AR terms | Humidity changes increased risk; rainfall and LST did not |
| São Paulo, Brazil, 2016 (PubMed 27598643) | State, 2007–2014 | Monthly | Bayesian time series, trigonometric seasonality | Seasonality | No | Warm-season concentration |
| Vilhena Neto et al., SSRN preprint (2025/26) | All Brazilian municipalities, 2007–2024 (~1.1M municipality-months) | Municipality-month | NB GAM, population offset | Temp, precipitation | [verify] | Effects differ **by climatic regime** ("one climate does not fit all") |
| Mato Grosso do Sul, medRxiv 2025 | State, 2007–2023 | Monthly | STL, Poisson/NB | Land use, climate, biome | [verify] | Jan–Apr peaks |
| Phillips, Lipman et al. 2019, *Clin Toxicol* 57(3) | California, 1997–2017 | County | Regression | Drought, precipitation, temperature | **Yes** (6 and 18 months) | −3.8% per 10% drought (6-month lag); +3.9% per 10% precipitation (18-month lag) |
| Mohapatra et al. 2011, *PLoS NTD* 5(4):e1018 | India, Million Death Study | National monthly | Correlation | Rainfall, Tmin, Tmax | No | r = 0.93 rainfall, 0.80 Tmin |
| Rahman et al. 2010, *PLoS NTD* 4(10):e860 | Rural Bangladesh | Monthly | Descriptive | Temp, rain | No | No association with monthly temperature or rain; harvest peak |
| India "big four" climate suitability, *Sci Rep* 2025 | India | Spatial | **GLMM** | Bioclimatic suitability | No | Suitability is positively related to incidence; precipitation seasonality dominant |
| Global VOI, *Current Zoology* 2026 | Global | Grid | NB GLMM | Bioclimate | No | Warmer, wetter, more seasonal areas have *lower* venomous-snake occurrence index |
| Effects of global change to 2050, *Lancet Planet Health* 2024 (PMC11327114) [verify authors] | Sri Lanka | Mechanistic | Snake–human contact model | Regional climate projections | n/a | −12% to −23% incidence by 2050 |
| Ecuador random forest, 2025 [verify] | Ecuador, 2014–2023 | — | ML | Climate | — | AUC 0.86 (validation design unclear) |

### 4.3 Ghana-specific evidence

| Study | Data | Design | Climate? | Finding |
|---|---|---|---|---|
| **Nyarko et al. 2026, medRxiv doi:10.64898/2026.07.12.26357875** [verify full author list] | **DHIMS-2, 261 districts, monthly 2020–2025** (very likely the same source as this dataset) | Bayesian spatio-temporal model in INLA: spatial, temporal and space-time interaction effects | Humidity, temperature, rainfall, NDVI (apparently **concurrent**) | Humidity and temperature increase risk; rainfall and NDVI not significant; Fanteakwa North highest-risk district in 2025; high-risk districts have poor treatment access |
| Musah et al. 2019, *PLoS NTD* | Savelugu-Nanton, community survey plus facility records | Descriptive / ecological | Rainfall | Rainy-season and farmland bites; **hump-shaped** rainfall–bite relationship |
| Volta/Oti 2019, *Pan Afr Med J* 40:131 | DHIMS 2014–2018 | Descriptive surveillance evaluation | No | 24 per 100,000; about 81% in rainy season; missed outbreaks |
| Volta 2018–2023, *TRSTMH* 119(4):443 | Facility data | Descriptive trends | No | Distribution and trends |
| Savannah Region 2018–2022, AFENET journal 2025 | DHIMS | Geospatial, temporal | No | 101 per 100,000; Central Gonja highest; about 55% in rainy season |
| Oti region antivenom use, 6-year retrospective (PMC11321883) | Facility | Descriptive | No | Antivenom utilisation |
| LSTM "Mapping Snakebite Risk in Ghana and Rwanda" (NCT06808789) | Facility data plus household surveys (Asante Akim South site) | Geostatistical risk mapping | Environmental covariates (time-varying use unclear) | Ongoing; **potential competitor**, see Section 9 |

**Key reading of the Ghana literature:**

* Before 2026, Ghana snakebite epidemiology was almost entirely descriptive and regional.
* The one nationwide analytical study (Nyarko et al. 2026) uses the same district-month DHIMS-2 frame. It models climate *contemporaneously*, with no exposure–lag structure, and its summary shows no non-linear climate functions.
* Its finding that **rainfall is not significant** conflicts with every descriptive Ghana and West African study, which show rainy-season peaks. Section 6 shows the likely reason: rainfall acts at a lag and through rainy-season *onset*, not through same-month totals.

---

## 5. Methodological review

### 5.1 Count likelihood

* **Overdispersion.** In this dataset the variance-to-mean ratio of cases is 29.1/3.27 ≈ 8.9. Poisson is inadequate, so use **negative binomial**: NB2 (`nbinom2`) or NB1. A moment estimate from the base model gives NB α ≈ 0.69.
* **Zeros.** 31.9% of district-months are zero. The median district has 25% zeros; one district (or more) has all zeros. Under NB the zero share is often adequately explained. Test **zero-inflated NB** or a **hurdle NB** only if the randomized-quantile residuals (DHARMa) show excess zeros. Zero inflation is plausible where *structural* zeros come from non-reporting.
* **Offset.** Use `offset(log(population))`. Population in this file is constant within district-year, and appears to be projections interpolated by year. Consider monthly linear interpolation as a sensitivity analysis.

### 5.2 Random-effects structure (the "mixed" part)

* Random intercept for **district nested in region**: `(1 | region/district)`.
* Optional **random slopes** for the key lagged exposure by ecological zone or region. This is where spatial heterogeneity in lag effects can be estimated (Section 8, innovation 3).
* **Temporal autocorrelation.** Lag-1 within-district autocorrelation of incidence is r ≈ 0.23. Options:
  * a lagged log-count term (beware Nickell-type bias with short panels)
  * a district-specific AR(1) random effect (`ar1(time + 0 | district)` in glmmTMB)
  * an RW1/RW2 term in INLA
* **Spatial autocorrelation.**
  * Bayesian: a BYM2 or ICAR district effect in R-INLA needs a district shapefile and adjacency matrix.
  * Frequentist: check Moran's I of district random effects; use `exp()` or `mat()` spatial covariance in glmmTMB if needed.

### 5.3 Seasonality is the main confounder of lag effects

Climate and snakebite share an annual cycle. Any lagged climate variable is therefore correlated with season, and lagged correlations flip sign mechanically. Rainfall lagged 6 months is anti-correlated with current-month rainfall.

This dataset shows it clearly. Unadjusted Spearman correlations of incidence with rainfall go from +0.10 at lag 0 to −0.10 at lags 4–5. Relative humidity goes from −0.02 to −0.17 at lag 4. These correlations reflect seasonal *phase*, not causal lags. Valid options:

1. **Zone-specific month fixed effects** or harmonic (Fourier) terms (`sin/cos(2πm/12)`, `sin/cos(4πm/12)` for the bimodal south) interacted with ecological zone.
2. **Anomaly decomposition (recommended):**
   * Split each covariate into a district × calendar-month **climatology** and an **anomaly**.
   * Climatology identifies the seasonal (and spatial) climate signal.
   * Anomalies identify the effect of *unusual* weather at each lag, which is the cleaner causal contrast for early warning.
3. **Case time-series design** (Gasparrini 2021, *Epidemiology* 32:829): district-specific strata absorb time-invariant confounders, and the lagged exposures are modelled with a DLNM.

### 5.4 Lag specification options (from weakest to strongest)

| Approach | Pros | Cons |
|---|---|---|
| Single-lag models, each lag tested separately | Simple; common in surveillance papers | Ignores confounding between lags; inflates false positives; double-counts |
| Moving averages or cumulative sums (e.g. rainfall over 0–2 months) | Robust | Assumes equal weights; hides lag shape |
| Unconstrained distributed lag (lags 0–L all in one model) | Mutual adjustment | Collinear lags; unstable |
| Constrained DLM (polynomial or spline over lag) | Stable and smooth lag curve | Assumes linear exposure–response |
| **DLNM** (Gasparrini, Armstrong, Kenward 2010, *Stat Med* 29:2224) | Non-linear exposure–response × lag via a cross-basis; overall cumulative RR; works inside GLM/GLMM/GAM | More choices: knots, max lag; needs sensitivity analysis |
| Penalized DLNM (Gasparrini et al. 2017, *Biometrics*) / Bayesian DLNM in INLA (Lowe et al. 2021; *GHRmodel*) | Data-driven smoothness; spatial random effects | Computation; interpretation |
| Spatial Bayesian DLNM (Quijal-Zamorano et al. 2024, *IJE* 53(3):dyae061) | Small-area, spatially varying exposure–lag–response | Heavier; mainly heat–mortality applications so far |

**Methodological precedent from infectious disease:**

* Lowe et al. 2021 (*Lancet Planet Health* 5:e209) fitted DLNMs inside a Bayesian hierarchical spatio-temporal model for 558 Brazilian microregions. They found dengue RR peaked 1 month after extreme wet conditions and 4 months after drought.
* In Ghana, negative-binomial GAMs of under-five malaria found lagged (1–3 months) and accumulated (3–6 months) rainfall outperformed same-month rainfall (PMC12918577 [verify]).

The same toolkit has, to our knowledge, **not been applied to snakebite anywhere.** Our searches found no snakebite DLNM. The closest is a scorpion-sting analysis in Brazil, and its full text was not confirmed.

### 5.5 Collinearity

Raw climate variables in this dataset are strongly correlated:

* RH vs Tmax: r = −0.80
* RH vs rainfall: r = 0.59
* Rainfall vs Tmax: r = −0.40
* T2M is close to the mean of Tmax and Tmin

Strategies:

1. Choose **one temperature metric**, using Tmax or a diurnal temperature range justified by snake thermal ecology.
2. Fit a **bivariate DLNM** or use joint cross-bases only for less-correlated pairs (e.g. rainfall + Tmax). Fit RH in a separate model and compare.
3. Use anomalies, which are less collinear than raw values (Section 6.4).
4. Report VIFs.
5. Consider a **compound index** (e.g. heat index or vapour-pressure deficit, VPD), which is physically meaningful for ectotherm water balance. VPD can be derived from T and RH.

### 5.6 Exposure data quality

* The climate fields look like **NASA POWER (MERRA-2-based, ~0.5° × 0.625°)**:
  * Rainfall values (0–31.6) match monthly-mean mm/day (PRECTOTCORR).
  * Each month, the 261 districts share only **71 distinct climate vectors**, so about 3.7 districts share each grid cell value.
  * Effective spatial resolution is therefore coarse. Standard errors should be clustered at the grid-cell level, or use a cell random effect.
  * In northern Ghana, **CHIRPS** (0.05°) matched gauge rainfall better than reanalysis, and **ERA5** beat MERRA-2 on temperature (Northern Ghana comparison, *Meteorol Appl* 2024 [verify]).
  * Re-extracting rainfall from CHIRPS and temperature/RH from ERA5-Land (0.1°) as a sensitivity analysis would strengthen the paper. It is itself a methodological contribution: reporting how sensitive inferences are to the exposure product.
* NDVI is district-specific (≈ 261 unique values per month), probably MODIS aggregated to district polygons.

---

## 6. What the dataset already shows

### 6.1 Structure and quality checks

| Item | Value |
|---|---|
| Districts / regions | 261 / 16 |
| Period | Jan 2020 – Nov 2025 (2025 has 11 months; 2849 rows for 259 districts) |
| Rows / cases | 18,485 / 60,515 |
| Incomplete series | Ayawaso East and Ledzokuku: 2020–2023 only (48 months) |
| All-zero district | 1 |
| Missing values | None |
| Zero share | 31.9% |
| Mean / variance of cases | 3.27 / 29.1 (overdispersed) |
| Extreme values | Max 234 (Bawku West, Jul 2020); 24 district-months > 20 cases and > 10× the district median. Check for reporting artefacts and run sensitivity analyses with and without them |
| Within-district lag-1 autocorrelation | 0.23 |
| National crude rate (2020–2024) | 32.4 per 100,000 per year |

**Highest regional rates (per 100,000 per year, 2020–24):**

| Region | Rate |
|---|---|
| Upper West | 111.9 |
| Savannah | 108.7 |
| North East | 73.0 |
| Western North | 61.7 |
| Upper East | 47.1 |

**Lowest:**

| Region | Rate |
|---|---|
| Greater Accra | 5.4 |
| Volta | 14.8 |

### 6.2 Seasonality differs by rainfall regime

Monthly total cases, north versus south. North = Northern, Savannah, North East, Upper East and Upper West (unimodal rainfall); south = the other 11 regions (bimodal).

| Month | J | F | M | A | M | J | J | A | S | O | N | D |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| North cases | 966 | 1018 | 2053 | 2229 | 2411 | 2567 | **2666** | 2028 | 1656 | 1724 | 1598 | 964 |
| South cases | 2605 | 2221 | 3593 | 3905 | **4077** | 3733 | 3579 | 2871 | 3307 | 3374 | 2855 | 2515 |
| North rain (mm/day) | 0.01 | 0.09 | 1.44 | 2.11 | 4.74 | 5.64 | 7.49 | 7.92 | **8.31** | 3.92 | 0.29 | 0.02 |
| South rain (mm/day) | 0.99 | 1.43 | 4.85 | 4.50 | 6.30 | **8.67** | 4.40 | 3.39 | 6.76 | **8.34** | 3.64 | 0.72 |

* **North:** cases rise in March, with the first rains, and peak in July. Rainfall peaks in September. Cases *lead* the rainfall peak, which is consistent with **onset-driven exposure** (land preparation and planting) rather than total rain.
* **South:** the major peak is in April–May, in the first rainy season. A second, smaller rise in September–October tracks the minor rainy season. This is a **bimodal echo** that a single national seasonal term would blur.

### 6.3 Rainy-season onset event study (descriptive)

Onset was defined as the first month from February with rainfall ≥ 2 mm/day (≈ 60 mm/month) in each district-year:

* **North:** median April
* **South:** median March

The table shows cases relative to the district mean, by months since onset.

| Months since onset | −3 | −2 | −1 | 0 | +1 | +2 | +3 | +4 | +5 |
|---|---|---|---|---|---|---|---|---|---|
| North | 0.49 | 0.80 | 1.04 | 1.09 | 1.23 | **1.74** | 1.28 | 1.05 | 1.03 |
| South | 0.75 | 0.77 | 0.75 | 1.01 | 1.22 | **1.25** | 1.20 | 1.07 | 0.94 |

Incidence peaks **1–2 months after onset**, with a 74% excess in the north at +2 months. This is the clearest lag signal in the data. It motivates modelling **onset timing** as an exposure in its own right (innovation 2 in Section 8).

### 6.4 Preliminary screen: lagged climate *anomalies* (negative binomial, population offset, district and zone × month fixed effects)

**Method (screen only, not the final analysis).**

* **Anomaly definition:** each covariate minus its district × calendar-month mean, divided by the SD of the anomaly.
* **Base model:** NB2 (α = 0.69) with district, ecological zone × calendar month and year fixed effects, plus offset log(population).
* **Screening:** each lagged anomaly (lags 0–6) was added one at a time, using the base model's linear predictor as the offset. Anomalies are orthogonal to district × month by construction, so this approximates a full refit.
* **Data:** 260 districts with at least 1 case; 16,877 district-months after losing 6 months per district to lags.
* **Interpretation:** RR per 1 SD anomaly; * = 95% CI excludes 1. Single-lag screens are **hypothesis-generating only** (Section 5.4).
* **Reproduce:** run `python3 analysis/prelim_lag_screen.py data_snake.csv`. The full output is in `analysis/prelim_lag_screen_output.txt`.

**Results: RR per 1 SD anomaly (95% CI)**

| Variable | Zone | Lag 0 | Lag 1 | Lag 2 | Lag 3 | Lag 4 | Lag 5 | Lag 6 |
|---|---|---|---|---|---|---|---|---|
| Rainfall | All | 1.00 | 1.015 | 1.00 | **1.017*** | 1.00 | 1.01 | 0.99 |
| | North | 1.00 | 1.00 | 1.01 | **1.056* (1.02–1.09)** | 0.99 | 1.02 | 0.97 |
| | South | 1.00 | **1.019* (1.00–1.04)** | 1.00 | 1.01 | 1.01 | 1.01 | 1.00 |
| Relative humidity | All | **1.033* (1.01–1.05)** | 1.014 | 1.00 | 1.01 | 0.99 | 1.00 | 1.00 |
| | North | **1.035*** | 1.01 | 1.00 | 1.027 | 0.99 | 1.02 | 1.00 |
| | South | **1.032*** | 1.017 | 1.00 | 1.00 | 0.99 | 0.99 | 0.99 |
| Tmin | All | **1.031*** | **1.025*** | 1.01 | 0.99 | 1.00 | 0.99 | 0.99 |
| | North | **1.045*** | 1.02 | **1.035*** | 1.02 | 0.99 | 0.99 | 0.97 |
| | South | **1.025*** | **1.029*** | 0.99 | **0.978*** | 1.00 | 1.00 | 1.00 |
| Tmax | All | 0.987 | 1.00 | 0.99 | 0.99 | 1.00 | 1.01 | 1.01 |
| | South | **0.979*** | 1.01 | 0.99 | 0.99 | 0.99 | 1.01 | 1.01 |
| T2M | All | **1.017*** | 1.015 | 1.00 | 0.99 | 1.00 | 1.00 | 0.99 |
| NDVI | All | 1.00 | **0.981*** | 1.00 | **1.027*** | 1.01 | 1.00 | **1.020*** |

The north Tmax row (no significant lags) and the zone-specific T2M and NDVI rows are omitted for space. They are in the screen output. As a validation check, exact full refits of the "All" rows gave nearly identical estimates. For example, RH at lag 0 was 1.039 (1.02–1.06) with a full refit, against 1.033 from the approximation. The approximation is slightly conservative.

**Preliminary interpretation (to be confirmed with DLNM-GLMM):**

1. **Seasonality carries most of the climate signal.** Once district × month climatology is removed, per-SD anomaly effects are modest (2–6%). The novel paper should therefore report *both* the climatology (between/seasonal) and the anomaly (within/weather) components, not only "the effect of rainfall". This also explains why concurrent raw rainfall can look null (Nyarko et al. 2026): its effect is seasonal and **delayed**.
2. **Rainfall acts with a delay, and the delay differs by rainfall regime.**
   * Unimodal north: an unusually wet month raises cases **3 months later** (RR 1.056 per SD).
   * Bimodal south: the effect appears at **lag 1** (RR 1.019).
   * This is the first quantitative hint of **regime-specific lag structure** (H4, gap G5). It is consistent with a prey/vegetation pathway that takes longer in the savanna.
3. **Humidity and night-time temperature act quickly (lag 0–1).**
   * This fits activity and refuge-seeking pathways A and D.
   * Hot daytime anomalies (Tmax) slightly *reduce* same-month risk in the south. This is consistent with thermal avoidance and supports a **non-linear** temperature term.
4. **NDVI shows an oscillating lag pattern:** negative at lag 1, positive at lags 3 and 6. This could reflect vegetation as cover versus vegetation as prey resource. It is a candidate for formal mediation analysis (gap G10).
5. **Caveats.**
   * These are 126 single-lag tests, so about 6 false positives are expected at α = 0.05.
   * The lags are not mutually adjusted.
   * Collinearity between anomalies is lower than between raw values but still material. RH vs Tmax anomaly correlation is r = −0.66, against −0.81 for raw values.
   * Standard errors ignore the shared NASA POWER grid cells, so the CIs are too narrow.
   * The DLNM-GLMM in Section 8 addresses all of these.

---

## 7. Gap analysis: what has not been done

| # | Gap | Evidence it is a gap |
|---|---|---|
| G1 | **No exposure–lag–response (DLNM) analysis of snakebite** anywhere, to our knowledge | Searches for snakebite + DLNM / distributed lag found none. Lags in the literature are single lags chosen by cross-correlation (Costa Rica) or fixed windows (California) |
| G2 | **No lagged climate analysis of snakebite in sub-Saharan Africa** | The systematic review flags SSA as under-represented. The Ghana nationwide preprint uses concurrent covariates |
| G3 | **Seasonal confounding is rarely separated from weather anomalies** | Most studies regress on raw climate with or without harmonics. None, to our knowledge, decompose climate into climatology and anomaly to separate "season" from "unusual weather" |
| G4 | **Rainy-season onset as an exposure** has not been modelled for snakebite | West African evidence links bites to farming at the start of the rains, but onset timing and false starts have never been used as a predictor |
| G5 | **Heterogeneity of lag structure across rainfall regimes** (bimodal vs unimodal) has not been quantified | Colombia (dry-season regions only) and Brazil (climatic regimes) show heterogeneity in *concurrent* effects; nobody has shown that the *lag* differs |
| G6 | **Climate-attributable snakebite burden** has not been estimated | The attributable-fraction methods for DLNMs (Gasparrini & Leone 2014) are standard in heat–mortality but unused in snakebite |
| G7 | **Out-of-sample forecasting and early warning** for snakebite are essentially absent | No study tested monthly forecasts on held-out years. Antivenom stock-outs in Ghana make lead time policy-relevant |
| G8 | **Sensitivity to the climate product** (reanalysis vs satellite) is not reported in snakebite studies | Coarse NASA POWER grid in this dataset; CHIRPS/ERA5 known to perform better in Ghana |
| G9 | **Non-linear (hump-shaped) rainfall effects** have been described only qualitatively | Northern Ghana community study (Musah et al. 2019) |
| G10 | **Mediation of rainfall through vegetation** (rain → NDVI → bites) has not been formally tested | NDVI is used as a parallel covariate (Nyarko 2026) rather than a lagged mediator |

---

## 8. Proposed novel study

### 8.1 Working titles (choose one)

1. *"Rain first, bites later: distributed-lag non-linear mixed models of climate and snakebite across 261 districts of Ghana, 2020–2025"*
2. *"Seasonal climatology versus weather anomalies: lagged climate effects, rainy-season onset and attributable burden of snakebite in Ghana"*
3. *"Climate-informed early warning for snakebite in West Africa: a nationwide distributed-lag GLMM from Ghana"*

### 8.2 Objectives

1. Estimate the **exposure–lag–response** associations of rainfall, relative humidity and temperature (lags 0–6 months; 0–12 in sensitivity) with district-month snakebite incidence. Use a negative-binomial GLMM with a population offset and district/region random effects. *(Core question.)*
2. **Decompose** each climate exposure into seasonal climatology and anomaly. Test whether unusual weather adds risk beyond the normal season. *(Novel: G3.)*
3. Quantify the effect of **rainy-season onset timing** on the timing and size of the annual snakebite surge. *(Novel: G4.)*
4. Test whether lag structures **differ between bimodal (south) and unimodal (north) rainfall regimes**. *(Novel: G5.)*
5. Estimate the **number and fraction of snakebites attributable** to non-optimal climate, by region. *(Novel: G6.)*
6. Evaluate **out-of-sample predictive skill** (train 2020–2024; test Jan–Nov 2025) and the usable lead time for antivenom pre-positioning. *(Novel: G7.)*

The minimum publishable unit is objectives 1 + 2 + 4. Objectives 3, 5 and 6 strengthen the paper towards a higher-impact journal or a second paper.

### 8.3 Hypotheses (pre-specify them)

* **H1.** Rainfall has a positive delayed effect, peaking at 1–2 months, and the cumulative exposure–response is non-linear (hump-shaped: very heavy rainfall months do not add risk).
* **H2.** Positive humidity anomalies raise same-month risk (lag 0). The effect is short-lived.
* **H3.** The temperature effect is non-linear. Risk rises with Tmax up to a threshold and falls at extremes, especially in the north.
* **H4.** The lag to peak risk is **longer in the unimodal north** than in the bimodal south.
* **H5.** Earlier onset brings the snakebite peak earlier. A "false start" (onset followed by a dry spell) changes the surge.
* **H6.** Adding lagged climate improves out-of-sample prediction over a seasonal-only baseline. Skill is meaningful at a 1–2-month lead.

### 8.4 Data preparation

1. **Clean.**
   * Remove or flag the all-zero district.
   * Handle Ayawaso East / Ledzokuku: keep 2020–2023, since GLMMs handle unbalanced panels.
   * Review the 24 extreme district-months with the DHIMS team.
   * Harmonise district names to a 261-district shapefile (needed for maps and spatial effects).
2. **Ecological zones.**
   * Map each district to an agro-ecological zone: Sudan savanna, Guinea savanna, transition, deciduous forest, rain forest, coastal savanna.
   * At minimum use the rainfall regime (unimodal north vs bimodal south).
   * Districts that straddle zones: assign by centroid.
3. **Exposure variables.**
   * Rainfall (mm/day monthly mean; convert to mm/month for interpretation).
   * RH (%), Tmax, Tmin, diurnal range (Tmax − Tmin).
   * VPD derived from T and RH.
   * NDVI.
   * For each, compute the district × calendar-month **climatology** and the standardised **anomaly**.
4. **Onset variables.** Per district-year:
   * onset month, using a threshold of 2 mm/day (sensitivity analyses at 1.5 and 3 mm/day, and a cumulative-rain definition)
   * "false start" flag: a month < 1 mm/day within the 2 months after onset
   * months-since-onset indicator for each district-month (−3 to +6)
5. **Lag matrices.** Build lag matrices *within district*. The data are contiguous with no gaps, so lags cross year boundaries correctly. Use `group = district` in `dlnm::crossbasis`. With 71 months per district and a maximum lag of 6, about 8% of rows are lost. To keep them, extend the climate series backwards to mid-2019 from NASA POWER/CHIRPS. **Recommended: climate is available before 2020 even if cases are not.**
6. **Optional enrichment.** CHIRPS rainfall and ERA5-Land T/RH for robustness; ENSO (ONI) and Atlantic SST indices; distance to the nearest antivenom-stocking facility.

### 8.5 Model specification

**Primary model: DLNM-GLMM (frequentist, `glmmTMB`)**

$$
\begin{aligned}
Y_{it} &\sim \text{NegBin}(\mu_{it}, \theta) \\
\log \mu_{it} &= \log(\text{Pop}_{it}) + \beta_0 + \underbrace{f_{\text{rain}}(R_{i,t-0:L})}_{\text{cross-basis}} + \underbrace{f_{\text{RH}}(H_{i,t-0:L})}_{\text{cross-basis}} + \underbrace{f_{\text{T}}(T_{i,t-0:L})}_{\text{cross-basis}} \\
&\quad + s_{z(i)}(\text{month}_t) + \gamma_{\text{year}(t)} + u_{r(i)} + v_{i} \\
u_r &\sim N(0, \sigma^2_u), \quad v_i \sim N(0, \sigma^2_v)
\end{aligned}
$$

* $L$ = 6 months in the main analysis; 3, 9 and 12 in sensitivity analyses.
* $s_{z(i)}$ = zone-specific seasonality: month × zone fixed effects or Fourier terms.
* The cross-basis uses a natural spline with 2–3 df on the exposure dimension and a natural spline with log-spaced knots on the lag dimension.
* **Anomaly version (objective 2):** replace raw exposures with anomalies inside the cross-basis, and add the district-month climatology as a separate (between) term. This is the "within-between" (Mundlak) decomposition applied to a DLNM. **To our knowledge it is new to environmental epidemiology of envenoming.**

**Heterogeneity by rainfall regime (objective 4).** Either:

* (a) fit the cross-basis interacted with zone, testing improvement by likelihood ratio or AIC; or
* (b) fit zone-specific models and pool them with multivariate meta-analysis (`mixmeta`), giving zone-specific and pooled lag curves with a test of heterogeneity (Cochran Q, I²).

**Bayesian alternative (spatial).** R-INLA with BYM2 district effects, RW1 month-of-year effects by zone, and the same cross-basis (via `GHRmodel` or by hand). This version is directly comparable to Nyarko et al. 2026 and shows what the *lagged* structure adds.

**Attributable burden (objective 5).** `attrdl()` (Gasparrini & Leone 2014) on the fitted cross-basis gives cases and fractions attributable to climate above or below the minimum-risk value, by region and year, with Monte-Carlo CIs.

**Onset model (objective 3).** Use one of:

* an **event-study GLMM**, with indicators for months since onset (−3 to +6) replacing month fixed effects, plus district random effects and year effects; or
* onset month as a district-year covariate predicting the **timing of the peak** (circular or linear mixed model) and the **seasonal total** (NB GLMM).

**Forecast evaluation (objective 6).**

* Use rolling-origin cross-validation on 2023–2025 and a hold-out of Jan–Nov 2025.
* Compare (i) a seasonal + random-effects baseline, (ii) + lagged climate, (iii) + onset.
* Metrics: MAE, RMSE, CRPS / logarithmic score, PIT histograms, 90% interval coverage, and a detection score for district outbreak months (exceeding the district's 75th percentile).
* Only lags ≥ 1 are usable for a one-month-ahead forecast. **The lag structure estimated in objective 1 sets the lead time directly.**

### 8.6 R code skeleton

```r
library(data.table); library(dlnm); library(glmmTMB); library(splines)
library(DHARMa); library(mixmeta)

d <- fread("data_snake.csv")
setnames(d, c("Relative Humidity","Maximum Temperature","Minimum Temperature"),
            c("RH","Tmax","Tmin"))
setorder(d, district, year, month)
d[, time := (year - 2020) * 12 + month]
north <- c("Northern","Upper East","Upper West","Savannah","North East")
d[, zone := factor(ifelse(region %in% north, "north", "south"))]
d <- d[, if (sum(cases) > 0) .SD, by = district]           # drop all-zero district

# climatology / anomaly decomposition
for (v in c("Rainfall","RH","Tmax","Tmin","ndvi")) {
  d[, paste0(v, "_clim") := mean(get(v)), by = .(district, month)]
  d[, paste0(v, "_anom") := get(v) - get(paste0(v, "_clim"))]
}

L <- 6
cb_rain <- crossbasis(d$Rainfall, lag = L, group = d$district,
                      argvar = list(fun = "ns", df = 3),
                      arglag = list(fun = "ns", knots = logknots(L, 2)))
cb_rh   <- crossbasis(d$RH,       lag = L, group = d$district,
                      argvar = list(fun = "ns", df = 3),
                      arglag = list(fun = "ns", knots = logknots(L, 2)))
cb_tmax <- crossbasis(d$Tmax,     lag = L, group = d$district,
                      argvar = list(fun = "ns", df = 3),
                      arglag = list(fun = "ns", knots = logknots(L, 2)))

m1 <- glmmTMB(cases ~ cb_rain + cb_tmax + zone:factor(month) + factor(year) +
                (1 | region/district) + offset(log(population)),
              family = nbinom2, data = d)
# m1b: swap cb_tmax for cb_rh (RH and Tmax r = -0.80); compare by AIC
# m2 : add ar1(factor(time) + 0 | district) for residual autocorrelation
# m3 : ziformula = ~1 (zero-inflated) if DHARMa shows excess zeros

# extract cross-basis coefficients for crosspred()
idx  <- grep("^cb_rain", names(fixef(m1)$cond))
pred <- crosspred(cb_rain, coef = fixef(m1)$cond[idx],
                  vcov = vcov(m1)$cond[idx, idx], model.link = "log",
                  at = seq(0, 15, 0.25), cen = median(d$Rainfall))
plot(pred, "contour"); plot(pred, "overall"); plot(pred, "slices", var = 8)

res <- simulateResiduals(m1); plot(res); testZeroInflation(res)
```

*Notes:*
* Rows with incomplete lag history get `NA` in the cross-basis and drop automatically. Extending climate back to 2019 recovers them (Section 8.4).
* For attributable fractions, source Gasparrini's `attrdl.R`.
* For zone pooling, fit by zone, use `crossreduce()` to the overall cumulative curve, then `mixmeta()`.

### 8.7 Sensitivity and robustness analyses (reviewers will ask)

1. Maximum lag 3, 9 and 12. Spline df on the exposure and lag dimensions (2–4).
2. NB1 vs NB2; zero-inflated and hurdle NB; quasi-Poisson GLM with district fixed effects (case time-series analogue).
3. Including vs excluding the 24 extreme district-months; excluding 2020 (possible COVID-19 effects on care-seeking and reporting).
4. Seasonality as Fourier terms vs month fixed effects; zone-specific vs national.
5. Alternative climate products (CHIRPS, ERA5-Land); grid-cell random effect or clustered SEs for the shared NASA POWER cells.
6. Monthly interpolated population offset.
7. Bayesian BYM2 spatial model vs non-spatial GLMM. Moran's I of residuals.
8. Negative control exposure: future climate (lag −1, −2) should show no association, as a falsification test of the lag structure.
9. Negative control outcome, if available from DHIMS: a non-climate-sensitive condition such as road-traffic injuries.

### 8.8 Planned figures and tables

* **Fig 1.** Map of the mean annual incidence rate by district, plus the regional climatology.
* **Fig 2.** Seasonal profiles of cases and rainfall, north vs south (Section 6.2).
* **Fig 3.** Exposure–lag–response 3-D or contour plots for rainfall, RH and Tmax.
* **Fig 4.** Lag-specific RR curves by rainfall regime (north vs south), with heterogeneity tests.
* **Fig 5.** Event-study plot: RR by months since rainy-season onset.
* **Fig 6.** Attributable fraction by region, plus out-of-sample 2025 forecast vs observed for selected districts.
* **Table 1.** Descriptives. **Table 2.** Model comparison (AIC, CV scores). **Table 3.** Cumulative RRs at the 10th, 90th and 99th percentiles. **Table 4.** Attributable cases.

### 8.9 Target journals

| Journal | Fit |
|---|---|
| *PLoS Neglected Tropical Diseases* | Core snakebite readership; open access; methods-friendly |
| *The Lancet Planetary Health* | If attributable burden and early warning are strong (cf. Lowe et al. 2021) |
| *International Journal of Epidemiology* | DLNM methods audience (cf. Quijal-Zamorano 2024; Ediriweera 2018) |
| *Transactions of the Royal Society of Tropical Medicine and Hygiene* | Snakebite 2030 special-issue momentum |
| *GeoHealth*, *Environmental Research*, *Science of the Total Environment*, *Toxicon* | Alternative climate-health and toxinology outlets |

### 8.10 Statement of novelty (draft paragraph for the Introduction)

> Although snakebite is widely described as seasonal and climate-sensitive, the timing of climate effects has rarely been quantified. To our knowledge, no study has applied distributed-lag non-linear models to snakebite incidence, separated seasonal climatology from weather anomalies, or treated rainy-season onset as an exposure. Few have examined lagged climate effects in sub-Saharan Africa, which bears nearly half of the global burden. A recent nationwide Ghanaian analysis modelled concurrent climate covariates and found no rainfall effect, contrary to consistent descriptive reports of rainy-season peaks. Using 71 months of surveillance data from all 261 districts of Ghana, we estimated exposure–lag–response relationships within a negative-binomial mixed model with a population offset. We tested whether lag structures differ between unimodal and bimodal rainfall regimes, estimated the climate-attributable burden and evaluated the out-of-sample predictive value of lagged climate for antivenom planning.

---

## 9. Threats to novelty and how to handle them

1. **Nyarko et al. 2026 (medRxiv)** uses the same national DHIMS-2 district-month frame (2020–2025, 261 districts).
   * Obtain the full text. Confirm whether lags or non-linear terms were used. If they were not, cite it as the motivating study and position the new paper as its lagged / anomaly / onset extension.
   * Contact the authors if the data are shared (possible collaboration or co-authorship).
   * Make sure the claim "rainfall is not significant contemporaneously but significant at lag 1–2 and via onset" is shown directly. It is the headline result.
2. **LSTM Ghana–Rwanda risk-mapping study (NCT06808789).** Primarily geostatistical and spatial (community surveys plus facility data). Check whether it includes time-varying climate; it probably targets spatial risk maps, not lag structure.
3. **Brazilian nationwide Bothrops study (Vilhena Neto et al.).** If it uses DLNMs, G1 must be reworded as "first in Africa / first for Old-World vipers". Check its full text.
4. **Formal search before submission.** Suggested string for PubMed/Scopus/Web of Science (also screen medRxiv, bioRxiv, SSRN and the African Journals Online database):
   `(snakebite OR "snake bite" OR envenom* OR ophidism) AND (lag* OR "distributed lag" OR DLNM OR delay* OR "time series") AND (rain* OR precipitation OR humidity OR temperature OR climat* OR weather)`
   Record the date, hits and screening in a PRISMA-style appendix. Reviewers respond well to a documented novelty search.

---

## 10. References (verify each before citing)

1. Collinson S, Lamb T, Cardoso…, Diggle PJ, Lalloo DG. A systematic review of variables associated with snakebite risk in spatial and temporal analyses. *Trans R Soc Trop Med Hyg* 2025; doi:10.1093/trstmh/trae131. [verify issue/pages]
2. Nyarko E, et al. Temporal and spatial patterns of snakebite envenoming in Ghana, 2020–2025: a nationwide surveillance analysis. *medRxiv* 2026; doi:10.64898/2026.07.12.26357875. [verify authors]
3. Chaves LF, Chuang TW, Sasa M, Gutiérrez JM. Snakebites are associated with poverty, weather fluctuations, and El Niño. *Sci Adv* 2015;1:e1500249.
4. Ediriweera DS, et al. Evaluating temporal patterns of snakebite in Sri Lanka: the potential for higher snakebite burdens with climate change. *Int J Epidemiol* 2018;47(6):2049–2058. doi:10.1093/ije/dyy188.
5. Bravo-Vega C, Santos-Vega M, Cordovez JM. Disentangling snakebite dynamics in Colombia: how does rainfall and temperature drive snakebite temporal patterns? *PLoS Negl Trop Dis* 2022;16(3):e0010270. [verify authors]
6. Increase in the risk of snakebites incidence due to changes in humidity levels: a time series study in four municipalities of the state of Rondônia. *Rev Soc Bras Med Trop* 2020 (PMC7094047). [verify authors]
7. Incidence of snakebites from 2007 to 2014 in the State of São Paulo, Brazil, using a Bayesian time series model. 2016 (PubMed 27598643). [verify]
8. Vilhena Neto A, et al. One climate does not fit all: temperature and precipitation influence *Bothrops* snakebite incidence differently across Brazilian climatic regimes. *SSRN* preprint (abstract 7386881). [verify]
9. Spatio-temporal dynamics of snakebite envenoming in Mato Grosso do Sul, Brazil (2007–2023). *medRxiv* 2025; doi:10.1101/2025.11.11.25339998. [verify]
10. Phillips C, Lipman GS, et al. Snakebites and climate change in California, 1997–2017. *Clin Toxicol* 2019;57(3). doi:10.1080/15563650.2018.1508690.
11. Mohapatra B, et al. Snakebite mortality in India: a nationally representative mortality survey. *PLoS Negl Trop Dis* 2011;5(4):e1018.
12. Rahman R, et al. Annual incidence of snake bite in rural Bangladesh. *PLoS Negl Trop Dis* 2010;4(10):e860.
13. Climate change triggering shifts in venomous snake hotspots and snakebite risk in India. *Sci Rep* 2025 (s41598-025-24731-z). [verify]
14. Global venomous snake redistribution and snakebite risk under climate change. *Curr Zool* 2026;72(4):579. [verify]
15. Effects of global change on snakebite envenoming incidence up to 2050: a modelling assessment. *Lancet Planet Health* 2024 (PMC11327114). [verify authors]
16. Ediriweera DS, Kasturiratne A, et al. Estimates of global burden of snakebite: a literature review and geostatistical modelling study. *PLoS Med* 2026;23(8):e1005201. [verify]
17. Kasturiratne A, et al. The global burden of snakebite: a literature analysis and modelling based on regional estimates of envenoming and deaths. *PLoS Med* 2008;5(11):e218.
18. Musah Y, Ameade EPK, Attuquayefio DK, Holbech LH. Epidemiology, ecology and human perceptions of snakebites in a savanna community of northern Ghana. *PLoS Negl Trop Dis* 2019;13(8):e0007221. [verify authors]
19. Analysis of snakebite data in Volta and Oti Regions, Ghana, 2019. *Pan Afr Med J* 2021;40:131 (PMC8641636).
20. Snakebites, a neglected public health concern: distribution, trends and incidence in the Volta Region of Ghana, 2018–2023. *Trans R Soc Trop Med Hyg* 2025;119(4):443.
21. Geospatial and temporal pattern of reported snakebite cases to health facilities in the Savannah Region, Ghana, 2018–2022. *J Interv Epidemiol Public Health* (AFENET) 2025;8(2):42.
22. Snakebites and antisnake venom utilization in Ghana's Oti Region: a 6-year retrospective study (PMC11321883). [verify]
23. Comprehensive review of epidemiology and treatment of snakebite envenomation in West Africa: case of Benin (PMC11018376).
24. Mapping Snakebite Risk in Ghana and Rwanda. ClinicalTrials.gov NCT06808789 (LSTM).
25. Gasparrini A, Armstrong B, Kenward MG. Distributed lag non-linear models. *Stat Med* 2010;29:2224–2234.
26. Gasparrini A. Modeling exposure–lag–response associations with distributed lag non-linear models. *Stat Med* 2014;33:881–899.
27. Gasparrini A, Scheipl F, Armstrong B, Kenward MG. A penalized framework for distributed lag non-linear models. *Biometrics* 2017;73:938–948.
28. Gasparrini A, Leone M. Attributable risk from distributed lag models. *BMC Med Res Methodol* 2014;14:55.
29. Gasparrini A. The case time series design. *Epidemiology* 2021;32(6):829–837.
30. Lowe R, et al. Combined effects of hydrometeorological hazards and urbanisation on dengue risk in Brazil: a spatiotemporal modelling study. *Lancet Planet Health* 2021;5(4):e209–e219.
31. Quijal-Zamorano M, et al. Spatial Bayesian distributed lag non-linear models (SB-DLNM) for small-area exposure-lag-response epidemiological modelling. *Int J Epidemiol* 2024;53(3):dyae061.
32. GHRmodel: Bayesian hierarchical modelling of spatio-temporal health data (incl. DLNM in R-INLA). CRAN package v0.1.1.
33. Brooks ME, et al. glmmTMB balances speed and flexibility among packages for zero-inflated generalized linear mixed modeling. *R J* 2017;9(2):378–400.
34. Hartig F. DHARMa: residual diagnostics for hierarchical regression models. CRAN.
35. Sera F, Armstrong B, Blangiardo M, Gasparrini A. An extended mixed-effects framework for meta-analysis. *Stat Med* 2019;38:5429–5444 (`mixmeta`).
36. Malaria incidence, severity and mortality in children under five in Ghana: evidence from generalised additive models (PMC12918577). [verify]
37. Comparative analysis of satellite and reanalysis data with ground-based observations in Northern Ghana. *Meteorol Appl* 2024. [verify]
38. Ghana Ministry of Food and Agriculture / FAO. Agro-ecological zones and rainfall regimes of Ghana (bimodal south; unimodal Guinea and Sudan savanna).
39. Bell A, Jones K. Explaining fixed effects: random effects modeling of time-series cross-sectional and panel data. *Political Sci Res Methods* 2015;3(1):133–153 (within–between decomposition).
