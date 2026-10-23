# MANUSCRIPT DRAFT

> **Draft v0.1, 23 October 2026.**
> * Target journal: *PLoS Neglected Tropical Diseases*, research article.
> * Reporting guideline: RECORD (STROBE extension for routinely collected health data).
> * Companion document: `REVIEW_DRAFT.md` (literature review, gap analysis, methods rationale, references).
> * **[RESULT]** = fill from the final models.
> * **[verify]** = check the citation against the full text.
> * **[AUTHOR]** = author decision or information needed.
> * Descriptive numbers already computed from `data_snake.csv` are filled in.

---

## Title

**Rain first, bites later: lagged and non-linear effects of climate on snakebite incidence across 261 districts of Ghana, 2020–2025**

*Alternative:* Seasonal climate, weather anomalies and rainy-season onset as drivers of snakebite in Ghana: a nationwide distributed-lag mixed-model study

**Running title:** Lagged climate effects on snakebite in Ghana

**Authors:** Pascal Antwi¹, [AUTHOR: co-authors] · ¹[AUTHOR: affiliation] · Corresponding author: [AUTHOR: email]

---

## Abstract

**Background.**
* Snakebite envenoming is a climate-sensitive neglected tropical disease. Sub-Saharan Africa bears nearly half of its global burden.
* Snakebite is consistently described as seasonal, yet the *timing* of climate effects (how long after a wet, humid or hot month risk rises) has rarely been quantified, and never in Africa.
* A recent nationwide Ghanaian analysis found no association with concurrent rainfall, even though bites peak clearly in the rainy season.

**Methodology.**
* We analysed 60,515 snakebite cases reported through Ghana's District Health Information Management System (DHIMS-2) from 261 districts, January 2020 – November 2025.
* Climate inputs were monthly district-level rainfall, relative humidity and temperature (NASA POWER) and vegetation (NDVI).
* Model: negative-binomial generalized linear mixed models with a population offset and district-within-region random effects.
* Distributed-lag non-linear models estimated exposure–lag–response associations over 0–[RESULT: L] months, with a pre-specified lag-selection strategy.
* We separated each climate variable into its seasonal climatology and its anomaly.
* We modelled rainy-season onset as an exposure and compared the unimodal north with the bimodal south.
* We estimated climate-attributable cases and evaluated out-of-sample predictive skill for 2025.

**Principal findings.**
* The crude incidence was 32.4 per 100,000 per year: 61.4 in the north and 25.6 in the south.
* Rainfall was associated with risk only after a delay, peaking at lag [RESULT] months in the north and lag [RESULT] in the south (cumulative RR [RESULT]).
* Humidity and minimum temperature acted within 0–1 months (RR [RESULT]). High maximum temperatures were associated with lower same-month risk.
* Incidence peaked 1–2 months after rainy-season onset, at [RESULT]% above baseline in the north.
* An estimated [RESULT]% of cases were attributable to non-optimal climate.
* Adding lagged climate improved one-month-ahead prediction (CRPS reduced by [RESULT]%).

**Conclusions/Significance.**
* Climate acts on snakebite in Ghana with measurable, regime-specific delays of one to three months.
* These delays provide usable lead time for climate-informed antivenom pre-positioning and community alerts in Ghana and similar West African settings.

**Keywords:** snakebite envenoming; climate; distributed lag non-linear model; generalized linear mixed model; rainfall onset; early warning; Ghana; West Africa

---

## Author summary

Snakebite kills and disables tens of thousands of people in Africa every year, mostly poor farmers in rural areas. People often say bites rise "in the rainy season". However, nobody had measured *how long after* rain, humidity or heat the risk goes up. That delay matters, because it tells health services how much warning they have to move antivenom to where it will be needed.

We used six years of monthly snakebite reports from every district in Ghana together with satellite climate data. We found that rain does not raise snakebite risk in the same month. Risk rises one to three months later, and the delay is longer in the dry savanna north than in the wetter south. Bites surged in the one to two months after the rains started, when farmers clear and plant their fields. Humid and warm nights were linked to more bites almost immediately, while very hot days were linked to fewer. Using past climate improved forecasts of the next month's snakebite cases.

These findings could help Ghana and neighbouring countries plan antivenom supplies and warn communities ahead of high-risk periods.

---

## 1. Introduction

**¶1 Burden.**
* Snakebite envenoming causes an estimated 2.1–7 million envenomings and 274,000–513,000 deaths each year once under-reporting is accounted for. Sub-Saharan Africa accounts for about 45% of envenomings and deaths [Ediriweera, Kasturiratne et al. 2026, verify; Kasturiratne et al. 2008].
* WHO re-listed snakebite as a category A neglected tropical disease in 2017. Its 2019 strategy aims to halve deaths and disability by 2030 [WHO 2019].
* In Ghana, about 10,000 snakebites are reported to health facilities each year. This is a lower bound, because many victims are treated by traditional healers [Graphic/KCCR, verify; Volta/Oti 2021].
* The West African carpet viper (*Echis ocellatus*) causes most severe envenoming in the savanna [Musah et al. 2019, verify].

**¶2 Why climate should act with a delay.**
* Snakes are ectotherms, so their activity, foraging and dispersal depend on temperature and moisture.
* Rainfall drives vegetation growth, then seed and insect pulses, then rodent prey, over weeks to months [Sahel rodents 2018].
* Human exposure follows the agricultural calendar: land clearing, planting and weeding begin with the rains and expose barefoot farmers [Benin review 2024; Musah et al. 2019].
* Flooding and humidity extremes may push snakes into dwellings.
* Each pathway implies a different delay, from weeks (activity) to months (prey dynamics). Pathways may even act in opposite directions at different lags.
* Studies that relate snakebite to *same-month* climate can therefore miss or mis-sign real effects.

**¶3 What is known.**
* A 2025 systematic review identified temperature and humidity as the climate variables most often associated with snakebite risk. It also noted inconsistent directions and few studies from sub-Saharan Africa [Collinson et al. 2025].
* Lagged effects have been examined only sporadically:
  * In Costa Rica, incidence rose 24% per °C one month after warm anomalies, and was associated with rainfall 11 months earlier [Chaves et al. 2015].
  * In California, bites fell after drought (6-month lag) and rose after wetter 18-month periods [Phillips et al. 2019].
  * In Colombia, rainfall drove incidence only where the dry season is marked [Bravo-Vega et al. 2022].
  * In Brazil, temperature effects differed between climatic regimes [Vilhena Neto et al., preprint].
* These studies chose lags by cross-correlation or fixed windows. To our knowledge, none has estimated a full exposure–lag–response relationship. Distributed-lag non-linear models (DLNMs) are standard for heat-related mortality and climate-sensitive infections such as dengue [Gasparrini et al. 2010; Lowe et al. 2021], but have not been applied to snakebite.

**¶4 The Ghana gap.**
* Regional analyses of Ghanaian surveillance data consistently show rainy-season concentration of bites: about 81% in Volta/Oti and about 55% in Savannah Region [Volta/Oti 2021; Savannah 2025].
* A recent nationwide Bayesian spatio-temporal analysis of the same district-month surveillance data modelled concurrent climate covariates. It found humidity and temperature, but not rainfall, associated with risk [Nyarko et al. 2026, verify].
* This apparent contradiction (a strongly rain-seasonal disease with no rainfall effect) suggests that rainfall acts with a delay and through the timing of the rainy season rather than through same-month totals.
* Ghana's two rainfall regimes (a single season in the savanna north, two seasons in the south) offer a natural contrast for testing whether lag structures differ by climate regime.

**¶5 Aim.** We aimed to quantify the delayed and non-linear effects of rainfall, humidity and temperature on snakebite incidence across all districts of Ghana. Specifically, we:
1. estimated exposure–lag–response associations using DLNMs within negative-binomial mixed models with a population offset;
2. separated seasonal climatology from weather anomalies;
3. assessed rainy-season onset as an exposure;
4. compared lag structures between unimodal and bimodal rainfall regimes;
5. estimated the climate-attributable burden;
6. evaluated whether lagged climate improves out-of-sample prediction.

---

## 2. Methods

### 2.1 Study setting

* Ghana (population about 34 million in 2025) is divided into 16 regions and 261 metropolitan, municipal and district assemblies.
* Rainfall regimes:
  * The Guinea and Sudan savanna zones of the north (Northern, Savannah, North East, Upper East and Upper West Regions; 55 districts) have a unimodal rainy season, mainly May–October, followed by a long dry season with the Harmattan.
  * The transition, forest and coastal zones of the south (11 regions; 206 districts) have a bimodal regime: a major season in March–July and a minor season in September–October [FAO/MoFA].
* Medically important snakes include *E. ocellatus*, *Bitis arietans*, *Naja* spp. and *Dendroaspis* spp. [AUTHOR: add Ghana species reference].
* Fig 1A shows the study area.

### 2.2 Study design and data

**Design.** This is a nationwide ecological panel (time-series cross-sectional) study of district-month snakebite counts, January 2020 – November 2025 (71 months).

**Outcome.**
* Source: monthly snakebite cases recorded in DHIMS-2 for each district.
* [AUTHOR: case definition / ICD code; facility types included; reporting completeness.]
* District boundaries follow the 2018 re-demarcation.
* Two districts (Ayawaso East, Ledzokuku) have data for 2020–2023 only. We retained their available months.
* One district reported no cases in any month and was excluded from models, because its district effect is not estimable.
* We flagged 24 district-months with more than 20 cases and more than 10 times the district median. [AUTHOR: verified with reporting units?] These were retained in the main analysis and excluded in a sensitivity analysis.

**Population.** Annual district population estimates [AUTHOR: source, e.g. Ghana Statistical Service projections from the 2021 Population and Housing Census] served as the offset.

**Climate and vegetation.**
* NASA POWER (MERRA-2-based; native grid about 0.5° × 0.625°) supplied monthly district values for:
  * precipitation (mm/day, monthly mean)
  * relative humidity at 2 m (%)
  * mean (T2M), maximum (Tmax) and minimum (Tmin) air temperature at 2 m (°C)
* [AUTHOR: extraction method, centroid or area-weighted.]
* Because of the native resolution, the 261 districts share 71 distinct climate values in any month.
* NDVI was obtained from [AUTHOR: e.g. MODIS MOD13A3] and averaged over each district.
* To provide full lag history for 2020 cases, climate series were extended back to January 2019 [AUTHOR: confirm extraction].
* For sensitivity analyses, rainfall was also taken from CHIRPS v2.0 (0.05°), and temperature and humidity from ERA5-Land (0.1°).

### 2.3 Derived exposures

**Climatology and anomaly.** For each climate variable $x$ in district $i$ and month $t$ with calendar month $m(t)$:
* the climatology $\bar{x}_{i,m(t)}$ is the district-specific mean for that calendar month over the study period;
* the anomaly is $a_{it} = x_{it} - \bar{x}_{i,m(t)}$, standardised by its SD.

The climatology captures the expected seasonal and spatial climate signal; the anomaly captures unusual weather.

**Rainy-season onset.** For each district-year, onset was the first month from February onward with mean rainfall ≥ 2 mm/day (≈ 60 mm/month).
* Alternative definitions: thresholds of 1.5 and 3 mm/day, and a cumulative-rainfall definition.
* A "false start" was an onset followed within two months by a month with < 1 mm/day.
* Each district-month was indexed by months since onset (−3 to +6).

**Derived thermal-moisture variables.** We derived the diurnal temperature range (Tmax − Tmin) and the vapour-pressure deficit (from T2M and RH) for secondary analyses.

### 2.4 Statistical analysis

#### 2.4.1 Descriptive analysis

* Incidence rates per 100,000 person-years by region, zone, year and calendar month.
* Seasonal profiles of cases and climate by zone.
* Overdispersion (variance-to-mean ratio) and the proportion of zero counts.

#### 2.4.2 Base model

Counts $Y_{it}$ were modelled as negative binomial (NB2) with mean $\mu_{it}$:

$$\log \mu_{it} = \log(\text{Pop}_{it}) + \beta_0 + s_{z(i)}(m_t) + \gamma_{y(t)} + u_{r(i)} + v_i,$$

where:
* $s_{z(i)}(m_t)$ is zone-specific seasonality (calendar-month effects interacted with rainfall regime);
* $\gamma_{y(t)}$ are year effects capturing secular trends and reporting changes, including the COVID-19 period;
* $u_{r} \sim N(0,\sigma_u^2)$ and $v_i \sim N(0,\sigma_v^2)$ are region and district random intercepts.

Residual temporal autocorrelation was assessed. Where present, it was addressed with a district-level AR(1) random effect.

#### 2.4.3 Distributed-lag non-linear models

* Each climate variable entered the base model as a cross-basis (Gasparrini et al. 2010).
* The cross-basis is the tensor product of:
  * a natural cubic spline over the exposure range; and
  * a natural cubic spline over lags 0 to $L$ months, with knots equally spaced on the log scale, which allows more flexibility at short lags.
* Lags were computed within districts across year boundaries.
* Because raw relative humidity and maximum temperature are strongly correlated (r = −0.80):
  * the main model included rainfall and one temperature metric;
  * humidity was assessed in an alternative model;
  * variance inflation factors are reported.
* We report:
  * lag-specific relative risks (RR) at the 90th and 99th percentiles of exposure versus the median (or the minimum-risk value);
  * the cumulative RR summed over all lags;
  * the overall cumulative exposure–response curve.

#### 2.4.4 Lag selection strategy (pre-specified)

To avoid the biases of single-lag testing and cross-correlation in strongly seasonal data, we pre-specified the following strategy:

1. **Maximum lag from mechanism.** The main analysis uses $L$ = 6 months, covering activity (0–1), agricultural-calendar (0–2) and vegetation–prey (1–4) pathways. Sensitivity analyses use 3, 9 and 12 months.
2. **Joint estimation.** All lags were estimated jointly within the cross-basis. We did not use separate single-lag models, cross-correlation or stepwise selection.
3. **Grid selection.** $L$ and the spline degrees of freedom were chosen from a pre-specified grid: $L \in \{3, 6, 9, 12\}$ × exposure df ∈ {2, 3, 4} × lag df ∈ {2, 3, 4}. Two criteria were used:
   * the Akaike information criterion, with all candidates fitted to identical observations;
   * leave-one-year-out cross-validation scored by the logarithmic score and continuous ranked probability score (CRPS).

   The most parsimonious model within 2 AIC units, or within 1 SE of the best cross-validated score, was retained.
4. **Penalized confirmation.** A penalized DLNM (Gasparrini et al. 2017) with $L$ = 12, fitted by restricted maximum likelihood, served as a data-driven check of the lag shape.
5. **Common specification.** The same $L$ and df were applied to all variables and zones, so lag curves are directly comparable.
6. **Falsification.** Future climate (lags −1 and −2) was added to the final model. No association was expected.

We report full lag curves and cumulative effects rather than a single "selected" lag.

#### 2.4.5 Climatology versus anomaly decomposition

* We refitted the DLNM with the standardised anomaly $a_{it}$ in the cross-basis and the climatology $\bar{x}_{i,m(t)}$ as a separate term. This is a within–between decomposition [Bell & Jones 2015].
* The anomaly terms estimate the delayed effect of unusual weather independently of normal seasonality.
* The climatology term captures the seasonal and spatial climate gradient.

#### 2.4.6 Heterogeneity by rainfall regime

* Lag structures were compared between the north (unimodal) and the south (bimodal).
* Method: fit zone-specific models, reduce each to its overall cumulative curve and its lag curve at a fixed exposure, and pool them by multivariate meta-analysis (`mixmeta`).
* Heterogeneity was summarised with Cochran's Q and I².
* A likelihood-ratio test of a zone × cross-basis interaction gave a complementary test.

#### 2.4.7 Rainy-season onset

* An event-study mixed model replaced calendar-month effects with months-since-onset indicators (−3 to +6; reference −3), estimated separately by zone, adjusting for year and district random effects.
* In secondary analyses, onset month (and false start) predicted:
  * the timing of the annual peak (linear mixed model); and
  * the total seasonal count (negative-binomial GLMM).

#### 2.4.8 Attributable burden

* Attributable numbers and fractions of cases were computed from the final DLNM (Gasparrini & Leone 2014), relative to the minimum-risk value of each exposure.
* Results are given by zone, region and year, with 95% empirical confidence intervals from 1,000 Monte-Carlo simulations.

#### 2.4.9 Predictive validation

* Models were trained on 2020–2024 and evaluated on January–November 2025, and in rolling-origin cross-validation.
* Three nested models were compared:
  * (A) seasonal terms + random effects;
  * (B) A + lagged climate restricted to lags ≥ 1, to mimic real-time use;
  * (C) B + onset terms.
* Metrics: mean absolute error, CRPS, 90% prediction-interval coverage, PIT histograms, and sensitivity and specificity for high-incidence months (above the district's 75th percentile).

#### 2.4.10 Sensitivity analyses

1. Maximum lag 3, 9 and 12, and alternative df.
2. NB1, zero-inflated and hurdle negative-binomial models.
3. Exclusion of the 24 flagged district-months, and of 2020 (COVID-19).
4. Fourier seasonal terms instead of month effects.
5. CHIRPS and ERA5-Land exposures.
6. Climate-grid-cell random effect or cluster-robust SEs (for districts sharing NASA POWER cells).
7. Monthly interpolated population offset.
8. Bayesian spatial model with BYM2 district effects in R-INLA.

#### 2.4.11 Diagnostics and software

* Model fit was checked with simulation-based randomized quantile residuals (DHARMa): dispersion, zero-inflation, temporal autocorrelation and spatial autocorrelation (Moran's I).
* Software: R [version] with `glmmTMB`, `dlnm`, `mgcv`, `mixmeta`, `DHARMa`, `sf` and `INLA`.
* Code will be available at [AUTHOR: GitHub/Zenodo DOI].

### 2.5 Ethics

* This study used aggregated, anonymised routine surveillance data. No individual-level data were accessed.
* [AUTHOR: Ghana Health Service Ethics Review Committee approval/waiver number; DHIMS-2 data-use permission.]

---

## 3. Results

### 3.1 Descriptive epidemiology

* **Totals.** From January 2020 to November 2025, 60,515 snakebite cases were reported from 261 districts (18,485 district-months).
* **Annual rates.** The national crude rate for 2020–2024 was 32.4 per 100,000 per year, declining from 35.2 in 2020 to 31.1 in 2024. The annualised rate for 2025 (11 months) was 24.1 (Table 1).
* **North vs south.** Incidence was 2.4 times higher in the unimodal north (61.4 per 100,000; 55 districts) than in the bimodal south (25.6; 206 districts).
* **Regional range.** Rates ranged from 5.4 per 100,000 (Greater Accra) to 111.9 (Upper West) and 108.7 (Savannah) (Fig 1B).
* **District range.** The median district rate was 26.2 per 100,000 (IQR 12.0–50.7). The highest was 277.5, in Mamprugu Moagduri.
* **Count distribution.** Monthly counts were overdispersed (mean 3.27, variance 29.1), and 31.9% of district-months had zero cases.

**Table 1. Snakebite cases and incidence, Ghana, 2020–2025**

| | Cases | Population (sum of districts) | Rate per 100,000 per year |
|---|---|---|---|
| 2020 | 11,084 | 31.4 M | 35.2 |
| 2021 | 10,783 | 32.1 M | 33.6 |
| 2022 | 10,054 | 32.7 M | 30.7 |
| 2023 | 10,545 | 33.3 M | 31.6 |
| 2024 | 10,463 | 33.7 M | 31.1 |
| 2025 (Jan–Nov) | 7,586 | 34.3 M | 24.1 (annualised) |
| North (unimodal), 2020–24 | 19,022 | — | 61.4 |
| South (bimodal), 2020–24 | 33,907 | — | 25.6 |
| **Total** | **60,515** | — | **32.4 (2020–24)** |

Climate summary (mean ± SD across district-months):
* rainfall: 4.34 ± 3.34 mm/day
* RH: 78.8 ± 12.9%
* Tmax: 32.8 ± 3.2 °C
* Tmin: 21.0 ± 2.9 °C
* NDVI: 0.49 ± 0.17

[AUTHOR: add a by-zone climate column.]

### 3.2 Seasonality

* **North.** Cases rose from March, with the first rains, and peaked in July (2,666 cases), two months *before* the rainfall peak in September (8.3 mm/day).
* **South.** The main peak was in May (4,077), during the major rainy season. A secondary rise in September–October coincided with the minor season (Fig 2).
* **Onset timing.** The median onset of the rainy season was April in the north and March in the south.
* **Post-onset surge.** Relative to the district mean, incidence rose to 1.23 one month after onset and 1.74 two months after onset in the north. In the south it rose to 1.22 and 1.25. In both zones it returned to about 1.0 by four to five months.

### 3.3 Lag selection

* [RESULT: grid of AIC and CV scores (Table 2 / S2 Table); selected L and df; agreement of penalized DLNM; falsification test (future lags) RR ≈ 1.]

### 3.4 Exposure–lag–response associations

* [RESULT: for each exposure, the lag at which RR peaks, the duration of the effect (lags with 95% CI excluding 1) and the cumulative RR at the 90th/99th percentile versus reference. Describe the shape: e.g. hump-shaped for rainfall; threshold for Tmax. Fig 3; Table 3.]

<!-- Preliminary single-lag anomaly screen (REVIEW_DRAFT.md §6.4), for orientation only:
     RH lag0 RR 1.033/SD; Tmin lag0–1 1.031, 1.025; Tmax lag0 south 0.979;
     rainfall lag3 north 1.056, lag1 south 1.019; NDVI lag1 0.981, lag3 1.027 -->

### 3.5 Seasonal climatology versus weather anomalies

* [RESULT: proportion of the climate effect explained by climatology vs anomaly; anomaly lag curves (Fig 4A); comparison with the concurrent-only model to show why rainfall appears null contemporaneously.]

### 3.6 Differences between rainfall regimes

* [RESULT: zone-specific lag curves (Fig 4B); peak lag north vs south; Cochran Q, I²; LRT p-value.]

### 3.7 Rainy-season onset

* [RESULT: event-study RRs by months since onset (Fig 5); effect of earlier/later onset on peak timing and seasonal total; false-start effect.]

### 3.8 Climate-attributable burden

* [RESULT: attributable number and fraction (95% eCI) by exposure, zone and region (Table 4).]

### 3.9 Predictive performance

* [RESULT: MAE/CRPS/coverage for models A–C on 2025 (Fig 6); gain from lagged climate; detection of high-incidence months; lead time.]

### 3.10 Sensitivity analyses

* [RESULT: one paragraph summarising robustness (S3–S6 Tables).]

---

## 4. Discussion

**¶1 Principal findings.** [RESULT-driven summary answering each of the six objectives in order. Lead with the headline: rainfall acts with a delay of 1–3 months that is longer in the north, and through onset; humidity and night temperature act immediately.]

**¶2 Mechanisms.**
* Short-lag effects of humidity and minimum temperature are consistent with increased nocturnal snake activity and refuge-seeking in humid, warm conditions.
* The negative same-month association with high Tmax suggests thermal avoidance at temperatures above the species' optimum, as the systematic review anticipated [Collinson et al. 2025].
* The 1–2-month post-onset surge matches the agricultural calendar: land preparation, planting and weeding.
* The longer rainfall lag in the north fits a delayed vegetation–rodent prey pulse after a single prolonged dry season [Sahel rodents].
* [Discuss the NDVI lag pattern: cover vs prey resource.]

**¶3 Comparison with previous studies.**
* *Costa Rica:* temperature at lag 1 agrees; the long rainfall lag (11 months) is outside our window [Chaves 2015].
* *Sri Lanka:* low humidity was associated with more bites, opposite in sign to our finding; this may reflect wet-zone saturation [Ediriweera 2018].
* *Colombia:* rainfall mattered where dry seasons are marked; the Ghanaian north is the analogue [Bravo-Vega 2022].
* *Brazil:* effects were regime-specific [Vilhena Neto].
* *California:* precipitation acted at long lags [Phillips 2019].
* *Ghana nationwide analysis:* our results reconcile its null concurrent-rainfall finding with descriptive rainy-season peaks [Nyarko 2026]. Rainfall's effect is delayed and seasonal, and concurrent models absorb it into seasonal and space-time random effects.

**¶4 Methodological contribution.**
* To our knowledge, this is the first application of distributed-lag non-linear models to snakebite.
* It is the first study to separate seasonal climatology from weather anomalies, and the first to treat rainy-season onset as an exposure.
* The pre-specified lag-selection strategy (joint estimation, information-criterion and cross-validated selection, penalized confirmation, falsification with future lags) avoids the seasonal-confounding artefacts of cross-correlation and single-lag testing. The same strategy is transferable to other envenomings and climate-sensitive NTDs.

**¶5 Public-health implications.**
* A lag of 1–3 months gives health services a practical window. Antivenom and health-worker training can be pre-positioned in northern districts about two months after onset, and in southern districts earlier, with a second, smaller window in September–October.
* Linking the model to Ghana Meteorological Agency seasonal and onset forecasts could create an operational early-warning system, in line with the WHO 2030 roadmap.
* High-burden districts with poor treatment access [Nyarko 2026] should be prioritised.

**¶6 Strengths and limitations.**
* *Strengths:*
  * nationwide coverage of all 261 districts over 71 months;
  * a hierarchical count model with a population offset;
  * flexible exposure–lag–response estimation;
  * explicit control of seasonal confounding;
  * out-of-sample validation;
  * extensive sensitivity analyses.
* *Limitations:*
  * facility-based surveillance under-counts bites treated by traditional healers, and completeness may vary between districts. District random effects absorb stable differences, but not changing ones.
  * The ecological design cannot attribute exposure to individuals.
  * Climate data are coarse (districts share grid cells), although results were robust to finer products [RESULT].
  * Six years are too few to study inter-annual drivers such as ENSO, or long (> 12-month) population lags.
  * DHIMS-2 lacks species, envenomation severity and outcome data.
  * The COVID-19 period may have altered care-seeking.
  * Population denominators are projections.

**¶7 Future research.**
* Species- and severity-specific outcomes.
* Linkage with antivenom stock and distribution data.
* Longer series to capture ENSO and Atlantic teleconnections.
* Prospective piloting of a climate-informed early-warning tool.
* Extension to neighbouring West African countries with similar rainfall regimes.

---

## 5. Conclusions

* Snakebite risk in Ghana responds to climate with measurable, regime-specific delays.
* Rainfall acts one to three months ahead and through the onset of the rainy season. Humidity and warm nights act within the same month, and extreme daytime heat suppresses risk.
* Modelling these delays explains why concurrent rainfall appears unrelated to a strongly rain-seasonal disease. It also provides lead time that can be used for climate-informed snakebite preparedness.

---

## Declarations

* **Data availability:** DHIMS-2 data are available from the Ghana Health Service on request [AUTHOR]. Climate data are publicly available (NASA POWER, CHIRPS, ERA5-Land, MODIS). Analysis code: [AUTHOR: repository/DOI].
* **Funding:** [AUTHOR]
* **Competing interests:** [AUTHOR]
* **Author contributions (CRediT):** [AUTHOR]
* **Acknowledgements:** Ghana Health Service; district health information officers. [AUTHOR]

---

## Figures and tables (planned)

| Item | Content |
|---|---|
| **Fig 1** | (A) Map of districts by rainfall regime; (B) district incidence map, with regional rates inset |
| **Fig 2** | Monthly cases vs rainfall, RH and temperature by zone (north/south) |
| **Fig 3** | Exposure–lag–response contour plots and overall cumulative curves (rainfall, RH or Tmax, Tmin) |
| **Fig 4** | (A) Anomaly lag curves; (B) north vs south lag curves |
| **Fig 5** | Event-study RR by months since rainy-season onset, by zone |
| **Fig 6** | 2025 observed vs predicted (example districts) and skill comparison of models A–C |
| **Table 1** | Cases and incidence by year and zone (above) |
| **Table 2** | Lag-selection grid summary (AIC, CV) |
| **Table 3** | Lag-specific and cumulative RRs |
| **Table 4** | Climate-attributable cases and fractions |

## Supplementary material (planned)

* S1 Text: RECORD checklist.
* S2 Text: data-cleaning log.
* S3 Text: novelty search protocol (PRISMA-style).
* S1 Table: districts and zone assignment.
* S2 Table: full lag-selection grid.
* S3–S6 Tables: sensitivity analyses.
* S1 Fig: DHARMa diagnostics.
* S2 Fig: climate product comparison.
* S3 Fig: falsification (future lags).
* S4 Fig: 3-D exposure–lag–response surfaces by zone.
* S5 Fig: district-level 2025 predictions.

## Writing order (suggested)

1. Finalise Methods 2.1–2.3 (data details).
2. Descriptive results → Table 1 and Figs 1–2.
3. Lag selection (2.4.4) → Table 2.
4. Main DLNM-GLMM → Fig 3 and Table 3.
5. Decomposition, regime and onset analyses → Figs 4–5.
6. Attribution and prediction → Table 4 and Fig 6.
7. Results text.
8. Discussion.
9. Re-check the Introduction against the full text of Nyarko et al. 2026 and a fresh novelty search.
10. Abstract, author summary and title last.

## References

See `REVIEW_DRAFT.md` Section 11 for the full reference list with verification flags. Convert to journal (Vancouver) style when finalising.
