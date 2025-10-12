# config.py
# Super demo-friendly hazard thresholds
HAZARD_THRESHOLDS = {
    "precipitation_mm": [10, 30, 60, 100],     # More realistic for heavy/extreme in PH
    "wind_speed_ms": [10, 15, 20, 25],         # Strong/very strong/extr. wind
    "temp_heat_c": [32, 35, 37, 39],           # Hot days are really rare at 35+
    "pressure_hpa": [995, 1000, 1005, 1008]    # Cyclone-level is <1000, normal >1006
}

# Model config (unchanged)
MODEL_CONFIG = {
    "random_state": 42,
    "selector_k": 12,
    "test_size": 0.2,
    "cv_splits": 5,
    "nb_var_smoothing": 1e-9,
    "use_mutual_info": True
}

MODEL_PATH = "model.pkl"
METADATA_PATH = "model_metadata.json"