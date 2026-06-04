# ERA5-Land vs CHELSA Bioclim Validation

10° × 10° crop in central North America (lon -100 to -90, lat 35 to 45).
ERA5-Land 41-year mean (1980-2020) vs CHELSA v2.1 climatology (1981-2010).

## Temperature: K → °C correction confirmed

ERA5-Land bioclim temperature variables are in **Kelvin** (not °C).
Subtract 273.15 to convert to °C.

| Variable | Description | r | RMSE | Fix |
|----------|------------|----|------|-----|
| bio01 | Annual mean temp | **0.9985** | 10.96°C | `-273.15` |
| bio05 | Max temp warmest month | **0.9976** | 28.09°C | `-273.15` |
| bio06 | Min temp coldest month | **0.9986** | 8.22°C | `-273.15` |
| bio08 | Mean temp wettest quarter | 0.7222 | 15.61°C | `-273.15` |
| bio09 | Mean temp driest quarter | 0.8598 | 8.42°C | `-273.15` |
| bio10 | Mean temp warmest quarter | **0.9972** | 21.93°C | `-273.15` |
| bio11 | Mean temp coldest quarter | **0.9994** | 3.86°C | `-273.15` |

**Shift-invariant** (no correction needed): bio02, bio03, bio04, bio07
(These are differences/ratios — same value in K or °C)

## Precipitation: Accumulation bug (~13× inflated)

ERA5-Land bioclim precipitation is not a unit issue — it's a computation bug.
ERA5 values are ~10-17× too high compared to CHELSA.

| Variable | r | Ratio |
|----------|----|-------|
| bio12 (annual) | 0.9477 | ×13.1 |
| bio13 (wettest month) | 0.8374 | ×18.8 |
| bio14 (driest month) | 0.8259 | ×8.0 |
| bio16 (wettest quarter) | 0.8731 | ×14.7 |
| bio17 (driest quarter) | 0.9219 | ×13.1 |
| bio18 (warmest quarter) | 0.7685 | ×11.0 |
| bio19 (coldest quarter) | 0.9902 | ×17.1 |

**Root cause:** ERA5-Land hourly precipitation is accumulated from forecast start.
The bioclim pipeline likely sums hourly values without proper de-accumulation,
causing monthly/quarterly/annual totals to be inflated by accumulating across
forecast cycles.

## Action Items

- [x] Validate temperature K→°C correction (r > 0.99 for key variables)
- [x] Confirm precipitation inflation (×10-17)
- [ ] Apply K→°C fix to xsdm env extraction pipeline
- [ ] Debug ERA5 bioclim precipitation computation (xclim pipeline)
- [ ] Re-extract precipitation variables with corrected pipeline
- [ ] Generate corrected env CSVs for Breviceps montanus test case

## Data Sources

- CHELSA v2.1: https://os.unil.cloud.switch.ch/chelsa02/chelsa/global/bioclim/
- ERA5-Land: /home/a474r867/scratch/era5-land/era5_bioclim/bioclim/
- Validation script: scripts/validate_era5_vs_chelsa.R
