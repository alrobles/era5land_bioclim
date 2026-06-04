#!/usr/bin/env Rscript
# validate_era5_vs_chelsa.R — Compare ERA5-Land bioclim vs CHELSA v2.1
# 10° crop in North America, 41-year ERA5 mean vs 1981-2010 CHELSA normals

suppressPackageStartupMessages(library(terra))

# ── Configuration ──
CHELSA_BASE <- "/vsicurl/https://os.unil.cloud.switch.ch/chelsa02/chelsa/global/bioclim"
ERA5_DIR    <- "/home/a474r867/scratch/era5-land/era5_bioclim/bioclim"
OUT_DIR     <- "/home/a474r867/scratch/chelsa_validation/results"

# 10° crop: Central North America (Great Plains)
EXT <- ext(-100, -90, 35, 45)  # lon_min, lon_max, lat_min, lat_max

YEARS_ERA5 <- 1980:2020  # 41 years
YEARS_CHELSA <- "1981-2010"

cat("══════════════════════════════════════════════════\n")
cat("ERA5-Land vs CHELSA Bioclim Validation\n")
cat(sprintf("Crop: lon %.0f-%.0f, lat %.0f-%.0f\n", EXT[1], EXT[2], EXT[3], EXT[4]))
cat("══════════════════════════════════════════════════\n\n")

# ── Step 1: Download CHELSA (crop via vsicurl) ──
cat("── Step 1: Loading CHELSA v2.1 ──\n")
chelsa_stack <- list()
for (i in 1:19) {
  bio_id <- sprintf("bio%02d", i)
  url <- sprintf("%s/%s/%s/CHELSA_%s_%s_V.2.1.tif",
                 CHELSA_BASE, bio_id, YEARS_CHELSA, bio_id, YEARS_CHELSA)
  cat(sprintf("  %s ...", bio_id))
  tryCatch({
    r <- rast(url)
    r_crop <- crop(r, EXT)
    chelsa_stack[[bio_id]] <- r_crop
    cat(sprintf(" OK (%.1f–%.1f)\n", minmax(r_crop)[1], minmax(r_crop)[2]))
  }, error = function(e) cat(sprintf(" FAILED: %s\n", conditionMessage(e))))
}

# ── Step 2: Load ERA5-Land and compute 41-year mean ──
cat("\n── Step 2: Computing ERA5-Land 41-year mean (1980-2020) ──\n")
era5_stack <- list()
for (i in 1:19) {
  bio_id <- sprintf("bio%02d", i)
  cat(sprintf("  %s ...", bio_id))
  tryCatch({
    year_rasters <- list()
    for (yr in YEARS_ERA5) {
      f <- file.path(ERA5_DIR, as.character(yr), sprintf("%s_%d.tif", bio_id, yr))
      if (file.exists(f)) {
        r <- rast(f)
        year_rasters[[length(year_rasters) + 1]] <- crop(r, EXT)
      }
    }
    if (length(year_rasters) > 0) {
      era5_mean <- mean(rast(year_rasters), na.rm = TRUE)
      era5_stack[[bio_id]] <- era5_mean
      cat(sprintf(" OK (%d yrs, %.1f–%.1f)\n", length(year_rasters),
                  minmax(era5_mean)[1], minmax(era5_mean)[2]))
    } else {
      cat(" NO DATA\n")
    }
  }, error = function(e) cat(sprintf(" FAILED: %s\n", conditionMessage(e))))
}

# ── Step 3: Unit conversion hypotheses ──
cat("\n── Step 3: Unit Analysis ──\n")

# CHELSA standard: temp = °C × 10 (divide by 10 for °C), precip = mm (or kg/m²)
# ERA5-Land raw: temp = K (subtract 273.15 for °C), precip after ×1000 = mm
# ERA5-Land (if K→°C was done): temp = °C

results <- data.frame(
  variable = character(), chelsa_min = numeric(), chelsa_max = numeric(),
  era5_min = numeric(), era5_max = numeric(),
  era5_corrected_min = numeric(), era5_corrected_max = numeric(),
  correction = character(), correlation = numeric(), rmse = numeric(),
  stringsAsFactors = FALSE
)

for (i in 1:19) {
  bio_id <- sprintf("bio%02d", i)
  if (is.null(chelsa_stack[[bio_id]]) || is.null(era5_stack[[bio_id]])) next

  # Resample CHELSA (30 arc-sec ~1 km) to ERA5-Land grid (0.1° ~9 km)
  # so both rasters have the same dimensions for cor()
  chelsa_r <- resample(chelsa_stack[[bio_id]], era5_stack[[bio_id]], method = "bilinear")

  c_vals <- values(chelsa_r, na.rm = TRUE)
  e_vals <- values(era5_stack[[bio_id]], na.rm = TRUE)

  is_temp <- (i <= 11)

  if (is_temp) {
    # Temperature: CHELSA is °C×10, ERA5 is K
    c_celsius <- c_vals / 10
    e_celsius <- e_vals - 273.15  # K → °C
    cor_val <- cor(c_celsius, e_celsius, use = "complete.obs")
    rmse_val <- sqrt(mean((c_celsius - e_celsius)^2, na.rm = TRUE))

    cat(sprintf("\n  %s (Temperature):\n", bio_id))
    cat(sprintf("    CHELSA:  %.1f–%.1f °C (raw ÷ 10)\n", min(c_celsius), max(c_celsius)))
    cat(sprintf("    ERA5:    %.1f–%.1f K → %.1f–%.1f °C\n",
                min(e_vals), max(e_vals), min(e_celsius), max(e_celsius)))
    cat(sprintf("    Correlation: %.4f | RMSE: %.2f °C\n", cor_val, rmse_val))

    results <- rbind(results, data.frame(
      variable = bio_id, chelsa_min = min(c_celsius), chelsa_max = max(c_celsius),
      era5_min = min(e_vals), era5_max = max(e_vals),
      era5_corrected_min = min(e_celsius), era5_corrected_max = max(e_celsius),
      correction = "K - 273.15 → °C", correlation = cor_val, rmse = rmse_val,
      stringsAsFactors = FALSE
    ))
  } else {
    # Precipitation: CHELSA is mm, ERA5 is mm (after ×1000 from m)
    cor_val <- cor(c_vals, e_vals, use = "complete.obs")
    rmse_val <- sqrt(mean((c_vals - e_vals)^2, na.rm = TRUE))

    cat(sprintf("\n  %s (Precipitation):\n", bio_id))
    cat(sprintf("    CHELSA:  %.0f–%.0f mm\n", min(c_vals), max(c_vals)))
    cat(sprintf("    ERA5:    %.0f–%.0f mm\n", min(e_vals), max(e_vals)))
    cat(sprintf("    Correlation: %.4f | RMSE: %.0f mm\n", cor_val, rmse_val))

    results <- rbind(results, data.frame(
      variable = bio_id, chelsa_min = min(c_vals), chelsa_max = max(c_vals),
      era5_min = min(e_vals), era5_max = max(e_vals),
      era5_corrected_min = NA, era5_corrected_max = NA,
      correction = "none (already mm)", correlation = cor_val, rmse = rmse_val,
      stringsAsFactors = FALSE
    ))
  }
}

# ── Step 4: Save results ──
write.csv(results, file.path(OUT_DIR, "validation_results.csv"), row.names = FALSE)
cat(sprintf("\n✅ Results saved: %s\n", file.path(OUT_DIR, "validation_results.csv")))

# ── Summary ──
cat("\n══════════════════════════════════════════════════\n")
cat("SUMMARY\n")
cat("══════════════════════════════════════════════════\n")
temp_rows <- results[results$variable %in% sprintf("bio%02d", 1:11), ]
prec_rows <- results[results$variable %in% sprintf("bio%02d", 12:19), ]

cat(sprintf("\nTemperature (bio01–bio11):\n"))
cat(sprintf("  Mean correlation: %.4f\n", mean(temp_rows$correlation, na.rm = TRUE)))
cat(sprintf("  Mean RMSE: %.2f °C\n", mean(temp_rows$rmse, na.rm = TRUE)))
cat(sprintf("  Correction needed: %s\n", temp_rows$correction[1]))

cat(sprintf("\nPrecipitation (bio12–bio19):\n"))
cat(sprintf("  Mean correlation: %.4f\n", mean(prec_rows$correlation, na.rm = TRUE)))
cat(sprintf("  Mean RMSE: %.0f mm\n", mean(prec_rows$rmse, na.rm = TRUE)))

cat("\n── RECOMMENDATION ──\n")
if (mean(temp_rows$correlation) > 0.90) {
  cat("✅ High correlation after K→°C correction. Apply subtract-273.15.\n")
} else {
  cat("⚠️ Low correlation. Verify ERA5 bioclim computation pipeline.\n")
}
