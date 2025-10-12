import requests
import time

OPENWEATHER_API_KEY = "98b876bdda3ba2bbf68d26d48a26b4b9"  # <-- Replace with your key
CITY = "San Pedro,PH"
PREDICT_API = "http://localhost:5000/predict"
INTERVAL = 60  # seconds

def main():
    while True:
        # 1. Get real-time weather from OpenWeather
        weather_url = f"http://api.openweathermap.org/data/2.5/weather"
        params = {"q": CITY, "appid": OPENWEATHER_API_KEY, "units": "metric"}
        resp = requests.get(weather_url, params=params)
        if not resp.ok:
            print("Failed to fetch weather:", resp.text)
            time.sleep(INTERVAL)
            continue
        weather_data = resp.json()

        # 2. Send to your prediction API
        pred_resp = requests.post(PREDICT_API, json=weather_data)
        pred = pred_resp.json() if pred_resp.ok else {"error": pred_resp.text}

        # 3. Print results
        print(f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] {CITY}")
        print("Weather:", weather_data.get("weather", [{}])[0].get("description", "N/A"))
        print("Temp:", weather_data.get("main", {}).get("temp"), "°C")
        print("Prediction:", pred.get("prediction", pred))
        print("-" * 40)

        # 4. Wait before next fetch
        time.sleep(INTERVAL)

if __name__ == "__main__":
    main()