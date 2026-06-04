# ERA5-Land vs CHELSA Bioclim Validation

10° × 10° crop in central North America (lon -100 to -90, lat 35 to 45).
ERA5-Land 41-year mean (1980-2020) vs CHELSA v2.1 climatology (1981-2010).

## Status: RE-RUNNING (job TBD)

Previous job 22347272 FAILED with "incompatible dimensions" — CHELSA (30 arc-sec)
and ERA5 (0.1°) have different grid sizes. Fixed by resampling CHELSA to ERA5
grid before computing correlations.

## Temperature: K → °C hypothesis

ERA5-Land bioclim temperature variables are expected in **Kelvin** (not °C).
If confirmed, subtract 273.15 to convert to °C.

Step 1-2 output suggests this is correct:
- bio01 CHELSA: 6.3–17.0 °C vs ERA5 raw: 279.3–290.2 K
- 279.3 - 273.15 = 6.15 °C ✓ matches CHELSA's lower bound
- 290.2 - 273.15 = 17.05 °C ✓ matches CHELSA's upper bound

Shift-invariant variables (no correction expected): bio02, bio03, bio04, bio07
(These are differences/ratios — same value in K or °C)

## Precipitation: Accumulation bug (~10-13× inflated)

ERA5-Land bioclim precipitation ranges are visibly inflated:
- bio12 CHELSA: 472–1,606 mm vs ERA5: 7,025–16,442 mm (~10-13×)

This is not a unit issue — it's a computation bug in the xclim pipeline.
ERA5-Land hourly precipitation is accumulated from forecast start.
The pipeline likely double-counts accumulation cycles.

Pending investigation.

## Action Items

- [ ] Fix validation script: add resample() before cor() — DONE
- [ ] Re-submit validation to HPC
- [ ] Populate this README with real correlation values
- [ ] Apply K→°C fix to xsdm env extraction pipeline
- [ ] Debug ERA5 bioclim precipitation computation (xclim pipeline)
- [ ] Re-extract precipitation variables with corrected pipeline

## Data Sources

- CHELSA v2.1: https://os.unil.cloud.switch.ch/chelsa02/chelsa/global/bioclim/
- ERA5-Land: /home/a474r867/scratch/era5-land/era5_bioclim/bioclim/
- Validation script: scripts/validate_era5_vs_chelsa.R
