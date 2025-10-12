# app.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import os

from model import train_from_csv, predict_from_features, features_from_openweather_json, determine_hazard_type, MODEL_PATH, METADATA_PATH

app = Flask(__name__)
CORS(app)

@app.route("/health")
def health():
    return jsonify({
        "status": os.path.exists(MODEL_PATH),
        "model_exists": os.path.exists(MODEL_PATH),
        "metadata_exists": os.path.exists(METADATA_PATH)
    })

@app.route("/train", methods=["POST"])
def train():
    """Train the model from a CSV file. Expects JSON: {"csv_path": "path/to.csv"}"""
    data = request.get_json()
    csv_path = data.get("csv_path")
    if not csv_path or not os.path.exists(csv_path):
        return jsonify({"error": "csv_path missing or file does not exist"}), 400
    meta = train_from_csv(csv_path)
    return jsonify({"status": "trained", "metrics": meta})

@app.route("/predict", methods=["POST"])
def predict():
    """Predict from OpenWeather API JSON (current weather)."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400
    weather_json = request.get_json()
    features = request.json
    result = predict_from_features(features)
    return jsonify({
        "status": "success",
        "prediction": result,
        "input_features": features
    })

@app.route("/predict_forecast", methods=["POST"])
def predict_forecast():
    """Predict for a list of OpenWeather forecast JSONs."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400
    data = request.get_json()
    forecasts = data.get("forecasts", [])
    results = []
    for fcast in forecasts:
        features = features_from_openweather_json(fcast)
        pred = predict_from_features(features)
        results.append({
            "timestamp": features["timestamp"].strftime("%Y-%m-%d %H:%M:%S"),
            "prediction": pred
        })
    return jsonify({"status": "success", "results": results})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)