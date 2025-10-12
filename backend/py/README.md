# Weather Early Warning System API

A minimal, robust, and presentable predictive API for binary weather event detection ("event" vs "no event") using Naive Bayes.  
Designed for easy integration with a Flutter app and clear demonstration to panelists.

---

## Features

- **REST API** (`Flask`): `/train`, `/predict`, `/predict_forecast`, `/health`
- **Editable hazard scoring**: Define what counts as an "event" in `config.py`
- **Good ML practices**: Honest train/test split, cross-validation, clear performance reporting
- **Robust feature alignment**: Safe for real-world API use
- **Forecast support**: Predict events for multiple future timepoints
- **CORS enabled** for frontend integration

---

## API Endpoints

### `/train` (POST)
Train or retrain the model from a CSV.

**Request:**
```json
{"csv_path": "balanced_training_data.csv"}
```
**Response:**  
Training accuracy, confusion matrix, cross-validation stats, etc.

---

### `/predict` (POST)
Predict from OpenWeather current weather JSON.

**Request:**  
Body: OpenWeather JSON (as returned from their API)

**Response:**  
- `event`: 0 or 1  
- `probability`: model confidence  
- `probabilities`: {"no_event": ..., "event": ...}

---

### `/predict_forecast` (POST)
Predict for a list of OpenWeather forecast points.

**Request:**  
```json
{
  "forecasts": [
    {...OpenWeather JSON...}, 
    {...OpenWeather JSON...}
  ]
}
```
**Response:**  
List of predictions with timestamps.

---

### `/health` (GET)
Check if the model is ready.

---

## How to Use

1. **Install requirements**
    ```
    pip install -r requirements.txt
    ```

2. **Train the model**
    - Place your CSV (e.g., `balanced_training_data.csv`) in the project directory.
    - Run:
      ```
      curl -X POST -H "Content-Type: application/json" -d '{"csv_path": "balanced_training_data.csv"}' http://localhost:5000/train
      ```

3. **Start the API**
    ```
    python app.py
    ```

4. **Connect from Flutter**
    - POST OpenWeather JSON to `/predict` endpoint and parse the response.

---

## How Hazard Detection Works

- The system **labels each training row** as "event" or "no event" using thresholds in `config.py`.
- The Naive Bayes model learns the pattern of these events.
- When new data comes in (live or forecast), the system computes features exactly as in training and returns its best prediction, with confidence.

---

## To Tweak/Experiment

- **Edit hazard thresholds** in `config.py` to match your domain or local climate.
- **Re-train** when you have new data or want to improve accuracy.
- **Read model performance** in the `/train` response or in `model_metadata.json`.

---

## Panelist Notes

- **Performance**: Honest accuracy and confusion matrix are reported.
- **Transparency**: Thresholds and features are documented and editable.
- **Explainability**: (Optional) You can return top-scoring features in the API (ask if you want this).

---

## Questions?
Open an issue or ask your Copilot for tweaks—this code is ready for real-world early warning MVPs!
