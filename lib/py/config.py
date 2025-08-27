# config.py
# Super demo-friendly hazard thresholds

HAZARD_THRESHOLDS = {
    # Rainfall (mm/hour): 1+ is light, 5+ is moderate, 10+ is heavy, 20+ is extreme
    "precipitation_mm": [1, 5, 10, 20],

    # Wind speed (m/s): 4+ is moderate, 8+ is strong, 12+ is very strong, 18+ is extreme
    "wind_speed_ms": [4, 8, 12, 18],

    # Heat index (°C): 28+ is hot, 31+ is very hot, 34+ is extreme, 37+ is record-breaking
    "temp_heat_c": [28, 31, 34, 37],

    # Pressure (hPa): <1010 is low, <1007 is very low, <1005 is cyclone-level, <1000 is extreme
    "pressure_hpa": [1000, 1005, 1007, 1010]
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