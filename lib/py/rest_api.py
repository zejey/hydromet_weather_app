from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import numpy as np
import joblib
import json
import os
from datetime import datetime, timedelta
import logging
from typing import Dict, List, Optional, Tuple
import traceback
from werkzeug.utils import secure_filename

# Import your weather forecasting model
try:
    from improved_weather_model import ImprovedWeatherForecaster
except ImportError:
    print("Warning: improved_weather_model not found. Make sure the file is in the same directory.")
    ImprovedWeatherForecaster = None

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter web apps

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
MAX_FILE_SIZE = 16 * 1024 * 1024  # 16MB
ALLOWED_EXTENSIONS = {'csv'}
UPLOAD_FOLDER = 'temp_uploads'

# Ensure upload folder exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Global variables
forecaster = None
model = None
model_metadata = None

def allowed_file(filename: str) -> bool:
    """Check if file has allowed extension"""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def validate_weather_data(data: Dict) -> Tuple[bool, Optional[str]]:
    """Validate weather data input"""
    required_fields = ['date', 'tavg', 'tmin', 'tmax', 'prcp', 'wspd', 'pres']
    numeric_fields = ['tavg', 'tmin', 'tmax', 'prcp', 'wspd', 'pres']
    
    # Check required fields
    missing_fields = [field for field in required_fields if field not in data]
    if missing_fields:
        return False, f'Missing required fields: {missing_fields}'
    
    # Validate date format
    try:
        datetime.strptime(data['date'], '%Y-%m-%d')
    except ValueError:
        return False, 'Date must be in YYYY-MM-DD format'
    
    # Validate numeric fields
    for field in numeric_fields:
        try:
            value = float(data[field])
            # Basic range validation
            if field in ['tavg', 'tmin', 'tmax'] and not -50 <= value <= 60:
                return False, f'Temperature {field} must be between -50°C and 60°C'
            elif field == 'prcp' and value < 0:
                return False, 'Precipitation cannot be negative'
            elif field == 'wspd' and not 0 <= value <= 200:
                return False, 'Wind speed must be between 0 and 200 km/h'
            elif field == 'pres' and not 800 <= value <= 1100:
                return False, 'Pressure must be between 800 and 1100 hPa'
        except (ValueError, TypeError):
            return False, f'Field {field} must be numeric'
    
    # Validate temperature consistency
    if data['tmin'] > data['tmax']:
        return False, 'Minimum temperature cannot be higher than maximum temperature'
    
    if not data['tmin'] <= data['tavg'] <= data['tmax']:
        return False, 'Average temperature must be between minimum and maximum temperatures'
    
    return True, None

def cleanup_temp_file(filepath: str) -> None:
    """Safely cleanup temporary file"""
    try:
        if os.path.exists(filepath):
            os.remove(filepath)
            logger.info(f"Cleaned up temporary file: {filepath}")
    except Exception as e:
        logger.warning(f"Failed to cleanup temporary file {filepath}: {e}")

def load_latest_model() -> bool:
    """Load the latest trained model"""
    global model, model_metadata, forecaster
    
    if ImprovedWeatherForecaster is None:
        logger.error("ImprovedWeatherForecaster class not available")
        return False
    
    try:
        forecaster = ImprovedWeatherForecaster()
        models_dir = forecaster.models_dir
        
        # Ensure models directory exists
        if not os.path.exists(models_dir):
            logger.error(f"Models directory {models_dir} not found")
            return False
        
        # Find the latest model
        latest_model_path = os.path.join(models_dir, "improved_weather_model_latest.pkl")
        
        if not os.path.exists(latest_model_path):
            logger.error("No trained model found. Please train a model first.")
            return False
        
        # Load model
        model = joblib.load(latest_model_path)
        logger.info(f"Model loaded from: {latest_model_path}")
        
        # Load metadata
        try:
            metadata_files = [f for f in os.listdir(models_dir) 
                            if f.startswith("metadata_v") and f.endswith(".json")]
            if metadata_files:
                latest_metadata = max(metadata_files)
                metadata_path = os.path.join(models_dir, latest_metadata)
                with open(metadata_path, 'r') as f:
                    model_metadata = json.load(f)
                logger.info(f"Metadata loaded from: {metadata_path}")
            else:
                logger.warning("No metadata file found")
                model_metadata = {}
        except Exception as e:
            logger.warning(f"Failed to load metadata: {e}")
            model_metadata = {}
        
        logger.info("Model loaded successfully")
        return True
            
    except Exception as e:
        logger.error(f"Error loading model: {e}")
        traceback.print_exc()
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None,
        'forecaster_available': forecaster is not None,
        'improvied_weather_model_available': ImprovedWeatherForecaster is not None,
        'timestamp': datetime.now().isoformat(),
        'api_version': '1.0.0'
    })

@app.route('/model/info', methods=['GET'])
def model_info():
    """Get information about the loaded model"""
    if model is None:
        return jsonify({'error': 'No model loaded'}), 400
    
    info = {
        'model_loaded': True,
        'hazard_levels': ['No Risk', 'Low Risk', 'Moderate Risk', 'High Risk', 'Extreme Risk']
    }
    
    if model_metadata:
        metrics = model_metadata.get('metrics', {})
        info.update({
            'model_type': model_metadata.get('model_type'),
            'version': model_metadata.get('version'),
            'training_date': model_metadata.get('training_date'),
            'accuracy': metrics.get('test_accuracy'),
            'f1_score': metrics.get('test_f1_weighted'),
            'roc_auc': metrics.get('test_roc_auc'),
            'training_samples': metrics.get('num_records')
        })
    
    return jsonify(info)

@app.route('/train', methods=['POST'])
def train_model():
    """Train a new model from uploaded CSV data"""
    try:
        if ImprovedWeatherForecaster is None:
            return jsonify({'error': 'Weather forecasting model not available'}), 500
        
        if 'file' not in request.files:
            return jsonify({'error': 'No file uploaded'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'error': 'Only CSV files are supported'}), 400
        
        # Secure filename and save
        filename = secure_filename(file.filename)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        temp_filename = os.path.join(UPLOAD_FOLDER, f"training_{timestamp}_{filename}")
        
        try:
            file.save(temp_filename)
            logger.info(f"Training file saved: {temp_filename}")
            
            # Validate CSV file can be read
            try:
                test_df = pd.read_csv(temp_filename, nrows=5)
                if test_df.empty:
                    return jsonify({'error': 'CSV file is empty'}), 400
            except Exception as e:
                return jsonify({'error': f'Invalid CSV file: {str(e)}'}), 400
            
            # Train model
            global forecaster
            forecaster = ImprovedWeatherForecaster()
            result = forecaster.train_model_from_csv(temp_filename)
            
            if result.get('status') == 'success':
                # Reload the new model
                if load_latest_model():
                    response_data = {
                        'status': 'success',
                        'message': 'Model trained successfully',
                        'model_version': result.get('version'),
                        'training_samples': result.get('training_samples', 0)
                    }
                    
                    # Add metrics if available
                    if 'metrics' in result:
                        response_data['metrics'] = {
                            'accuracy': result['metrics'].get('test_accuracy'),
                            'f1_score': result['metrics'].get('test_f1_weighted'),
                            'roc_auc': result['metrics'].get('test_roc_auc')
                        }
                    
                    return jsonify(response_data)
                else:
                    return jsonify({'error': 'Model trained but failed to reload'}), 500
            else:
                error_msg = result.get('error', 'Training failed')
                return jsonify({'error': error_msg}), 500
                
        finally:
            cleanup_temp_file(temp_filename)
            
    except Exception as e:
        logger.error(f"Training error: {e}")
        traceback.print_exc()
        return jsonify({'error': f'Training failed: {str(e)}'}), 500

@app.route('/predict/single', methods=['POST'])
def predict_single():
    """Make prediction for a single day's weather data"""
    try:
        if model is None or forecaster is None:
            return jsonify({'error': 'No model loaded'}), 400
        
        data = request.json
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        # Validate input data
        is_valid, error_msg = validate_weather_data(data)
        if not is_valid:
            return jsonify({'error': error_msg}), 400
        
        # Create DataFrame from input data
        df = pd.DataFrame([data])
        
        # Process data using forecaster
        try:
            processed_data = forecaster.preprocess_csv_data(df.copy())
        except Exception as e:
            logger.error(f"Data preprocessing error: {e}")
            return jsonify({'error': f'Data preprocessing failed: {str(e)}'}), 400
        
        if processed_data.empty:
            return jsonify({'error': 'Could not process input data'}), 400
        
        # Prepare features
        feature_columns = [col for col in processed_data.columns 
                          if col not in [forecaster.target_column, 'timestamp'] and 
                          not col.endswith('_category')]
        
        if not feature_columns:
            return jsonify({'error': 'No valid features found after preprocessing'}), 400
        
        X = processed_data[feature_columns].fillna(0)
        
        # Make prediction
        try:
            prediction = model.predict(X)[0]
            probabilities = model.predict_proba(X)[0]
        except Exception as e:
            logger.error(f"Model prediction error: {e}")
            return jsonify({'error': f'Prediction failed: {str(e)}'}), 500
        
        hazard_levels = ['No Risk', 'Low Risk', 'Moderate Risk', 'High Risk', 'Extreme Risk']
        
        return jsonify({
            'date': data['date'],
            'hazard_level': int(prediction),
            'hazard_description': hazard_levels[int(prediction)],
            'confidence': float(probabilities[int(prediction)]),
            'all_probabilities': {
                level: float(prob) for level, prob in zip(hazard_levels, probabilities)
            }
        })
        
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        traceback.print_exc()
        return jsonify({'error': f'Prediction failed: {str(e)}'}), 500

@app.route('/predict/batch', methods=['POST'])
def predict_batch():
    """Make predictions for multiple days from CSV data"""
    try:
        if model is None or forecaster is None:
            return jsonify({'error': 'No model loaded'}), 400
        
        if 'file' not in request.files:
            return jsonify({'error': 'No file uploaded'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'error': 'Only CSV files are supported'}), 400
        
        # Secure filename and save
        filename = secure_filename(file.filename)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        temp_filename = os.path.join(UPLOAD_FOLDER, f"prediction_{timestamp}_{filename}")
        
        try:
            file.save(temp_filename)
            logger.info(f"Prediction file saved: {temp_filename}")
            
            # Validate CSV file
            try:
                test_df = pd.read_csv(temp_filename, nrows=5)
                if test_df.empty:
                    return jsonify({'error': 'CSV file is empty'}), 400
            except Exception as e:
                return jsonify({'error': f'Invalid CSV file: {str(e)}'}), 400
            
            # Make predictions
            latest_model_path = os.path.join(forecaster.models_dir, "improved_weather_model_latest.pkl")
            result = forecaster.predict_from_csv(latest_model_path, temp_filename)
            
            # Format results
            hazard_levels = ['No Risk', 'Low Risk', 'Moderate Risk', 'High Risk', 'Extreme Risk']
            predictions = []
            
            for i, (date, pred, probs) in enumerate(zip(
                result['timestamps'], 
                result['predictions'], 
                result['probabilities']
            )):
                predictions.append({
                    'date': date,
                    'hazard_level': int(pred),
                    'hazard_description': hazard_levels[int(pred)],
                    'confidence': float(probs[int(pred)]),
                    'all_probabilities': {
                        level: float(prob) for level, prob in zip(hazard_levels, probs)
                    }
                })
            
            return jsonify({
                'predictions': predictions,
                'total_predictions': len(predictions)
            })
            
        finally:
            cleanup_temp_file(temp_filename)
        
    except Exception as e:
        logger.error(f"Batch prediction error: {e}")
        traceback.print_exc()
        return jsonify({'error': f'Batch prediction failed: {str(e)}'}), 500

@app.route('/predict/forecast', methods=['POST'])
def predict_forecast():
    """Generate weather hazard forecast for next N days based on current trends"""
    try:
        if model is None or forecaster is None:
            return jsonify({'error': 'No model loaded'}), 400
        
        data = request.json
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        days_ahead = data.get('days_ahead', 7)
        base_data = data.get('current_weather', {})
        
        if not base_data:
            return jsonify({'error': 'Current weather data required'}), 400
        
        # Validate days_ahead
        if not isinstance(days_ahead, int) or days_ahead < 1 or days_ahead > 30:
            return jsonify({'error': 'days_ahead must be an integer between 1 and 30'}), 400
        
        # Validate base weather data
        is_valid, error_msg = validate_weather_data(base_data)
        if not is_valid:
            return jsonify({'error': f'Invalid current_weather data: {error_msg}'}), 400
        
        # Generate forecast based on current conditions and trends
        forecast_data = []
        base_date = datetime.strptime(base_data['date'], '%Y-%m-%d')
        
        # Set random seed for reproducible results
        np.random.seed(42)
        
        for i in range(1, days_ahead + 1):
            # Simple trend-based forecasting with seasonal adjustments
            forecast_date = base_date + timedelta(days=i)
            
            # Add seasonal and daily variability
            day_of_year = forecast_date.timetuple().tm_yday
            seasonal_temp_adj = 10 * np.sin(2 * np.pi * day_of_year / 365.25)
            
            temp_variation = np.random.normal(0, 2)  # ±2°C variation
            precip_factor = max(0, 1 + np.random.normal(0, 0.3))  # Precipitation variability
            wind_factor = max(0.1, 1 + np.random.normal(0, 0.2))  # Wind variability
            
            forecast_weather = {
                'date': forecast_date.strftime('%Y-%m-%d'),
                'tavg': float(base_data['tavg']) + temp_variation + seasonal_temp_adj * 0.1,
                'tmin': float(base_data['tmin']) + temp_variation - 2 + seasonal_temp_adj * 0.1,
                'tmax': float(base_data['tmax']) + temp_variation + 2 + seasonal_temp_adj * 0.1,
                'prcp': max(0, float(base_data.get('prcp', 0)) * precip_factor),
                'wspd': max(0, float(base_data.get('wspd', 10)) * wind_factor),
                'pres': float(base_data.get('pres', 1013)) + np.random.normal(0, 5),
                'wdir': float(base_data.get('wdir', 180)),
                'wpgt': max(0, float(base_data.get('wpgt', base_data.get('wspd', 10))) * wind_factor * 1.3)
            }
            
            forecast_data.append(forecast_weather)
        
        # Create DataFrame and make predictions
        df = pd.DataFrame(forecast_data)
        
        try:
            processed_data = forecaster.preprocess_csv_data(df.copy())
        except Exception as e:
            logger.error(f"Forecast preprocessing error: {e}")
            return jsonify({'error': f'Forecast preprocessing failed: {str(e)}'}), 500
        
        if processed_data.empty:
            return jsonify({'error': 'Could not process forecast data'}), 400
        
        feature_columns = [col for col in processed_data.columns 
                          if col not in [forecaster.target_column, 'timestamp'] and 
                          not col.endswith('_category')]
        
        X = processed_data[feature_columns].fillna(0)
        
        try:
            predictions = model.predict(X)
            probabilities = model.predict_proba(X)
        except Exception as e:
            logger.error(f"Forecast prediction error: {e}")
            return jsonify({'error': f'Forecast prediction failed: {str(e)}'}), 500
        
        hazard_levels = ['No Risk', 'Low Risk', 'Moderate Risk', 'High Risk', 'Extreme Risk']
        forecast_results = []
        
        for i, (weather, pred, probs) in enumerate(zip(forecast_data, predictions, probabilities)):
            forecast_results.append({
                'date': weather['date'],
                'predicted_weather': {
                    'temperature': round(weather['tavg'], 1),
                    'temperature_min': round(weather['tmin'], 1),
                    'temperature_max': round(weather['tmax'], 1),
                    'precipitation': round(weather['prcp'], 1),
                    'wind_speed': round(weather['wspd'], 1),
                    'pressure': round(weather['pres'], 1)
                },
                'hazard_level': int(pred),
                'hazard_description': hazard_levels[int(pred)],
                'confidence': float(probs[int(pred)]),
                'risk_factors': _identify_risk_factors(weather, int(pred))
            })
        
        return jsonify({
            'forecast': forecast_results,
            'forecast_period': f"{days_ahead} days",
            'base_date': base_data['date'],
            'generated_at': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Forecast error: {e}")
        traceback.print_exc()
        return jsonify({'error': f'Forecast generation failed: {str(e)}'}), 500

def _identify_risk_factors(weather_data: Dict, hazard_level: int) -> List[str]:
    """Identify key risk factors contributing to the hazard level"""
    risk_factors = []
    
    prcp = weather_data.get('prcp', 0)
    wspd = weather_data.get('wspd', 0)
    tavg = weather_data.get('tavg', 20)
    tmax = weather_data.get('tmax', 25)
    tmin = weather_data.get('tmin', 15)
    
    # Precipitation factors
    if prcp > 50:
        risk_factors.append("Very heavy precipitation expected")
    elif prcp > 25:
        risk_factors.append("Heavy precipitation expected")
    elif prcp > 10:
        risk_factors.append("Moderate precipitation expected")
    
    # Wind factors
    if wspd > 50:
        risk_factors.append("Very strong winds")
    elif wspd > 30:
        risk_factors.append("Strong winds")
    elif wspd > 20:
        risk_factors.append("Moderate winds")
    
    # Temperature factors
    if tmax > 40:
        risk_factors.append("Extreme heat")
    elif tmax > 35:
        risk_factors.append("Very high temperatures")
    elif tmax > 30:
        risk_factors.append("High temperatures")
    
    if tmin < -10:
        risk_factors.append("Extreme cold")
    elif tmin < -5:
        risk_factors.append("Very cold temperatures")
    elif tmin < 0:
        risk_factors.append("Freezing temperatures")
    
    # Temperature variation
    temp_range = abs(tmax - tmin)
    if temp_range > 25:
        risk_factors.append("Extreme temperature swing")
    elif temp_range > 20:
        risk_factors.append("Large temperature swing")
    elif temp_range > 15:
        risk_factors.append("Moderate temperature variation")
    
    # Default factors based on hazard level
    if not risk_factors and hazard_level > 2:
        risk_factors.append("Multiple weather factors combined")
    elif not risk_factors and hazard_level > 0:
        risk_factors.append("Minor weather concerns")
    elif not risk_factors:
        risk_factors.append("Stable weather conditions")
    
    return risk_factors

@app.route('/api/docs', methods=['GET'])
def api_docs():
    """API documentation endpoint"""
    docs = {
        'title': 'Weather Hazard Forecasting API',
        'version': '1.0.0',
        'description': 'REST API for weather hazard prediction and forecasting',
        'endpoints': {
            'GET /health': {
                'description': 'Health check - returns API status',
                'parameters': None,
                'response': 'JSON with status information'
            },
            'GET /model/info': {
                'description': 'Get information about the loaded model',
                'parameters': None,
                'response': 'JSON with model metadata and performance metrics'
            },
            'POST /train': {
                'description': 'Train new model from CSV file upload',
                'parameters': 'multipart/form-data with CSV file',
                'response': 'JSON with training results and metrics'
            },
            'POST /predict/single': {
                'description': 'Make prediction for single weather record',
                'parameters': 'JSON with weather data',
                'response': 'JSON with hazard prediction and confidence'
            },
            'POST /predict/batch': {
                'description': 'Make predictions for CSV file upload',
                'parameters': 'multipart/form-data with CSV file',
                'response': 'JSON with array of predictions'
            },
            'POST /predict/forecast': {
                'description': 'Generate multi-day forecast',
                'parameters': 'JSON with current weather and days_ahead',
                'response': 'JSON with forecast array'
            },
            'GET /api/docs': {
                'description': 'This documentation',
                'parameters': None,
                'response': 'JSON with API documentation'
            }
        },
        'data_format': {
            'required_fields': ['date', 'tavg', 'tmin', 'tmax', 'prcp', 'wspd', 'pres'],
            'optional_fields': ['wdir', 'wpgt', 'snow', 'tsun'],
            'date_format': 'YYYY-MM-DD',
            'temperature_units': 'Celsius',
            'precipitation_units': 'mm',
            'wind_speed_units': 'km/h',
            'pressure_units': 'hPa'
        },
        'hazard_levels': {
            0: 'No Risk',
            1: 'Low Risk',
            2: 'Moderate Risk',
            3: 'High Risk',
            4: 'Extreme Risk'
        },
        'example_requests': {
            'single_prediction': {
                'date': '2024-01-15',
                'tavg': 25.0,
                'tmin': 18.0,
                'tmax': 32.0,
                'prcp': 0.0,
                'wspd': 15.0,
                'pres': 1013.2
            },
            'forecast': {
                'days_ahead': 7,
                'current_weather': {
                    'date': '2024-01-15',
                    'tavg': 25.0,
                    'tmin': 18.0,
                    'tmax': 32.0,
                    'prcp': 0.0,
                    'wspd': 15.0,
                    'pres': 1013.2
                }
            }
        }
    }
    return jsonify(docs)

@app.errorhandler(400)
def bad_request(error):
    return jsonify({'error': 'Bad request'}), 400

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(413)
def payload_too_large(error):
    return jsonify({'error': 'File too large'}), 413

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    print("Weather Hazard Forecasting API")
    print("=" * 40)
    
    # Check if ImprovedWeatherForecaster is available
    if ImprovedWeatherForecaster is None:
        print("⚠️  Warning: ImprovedWeatherForecaster not available")
        print("   Make sure 'improved_weather_model.py' is in the same directory")
        print("   API will start but training and prediction may not work")
        print()
    
    # Load model on startup
    model_loaded = load_latest_model()
    
    if model_loaded:
        print("✓ Model loaded successfully")
    else:
        print("❌ No trained model found!")
        print("  You can still use the API to train a new model")
    
    print("✓ API server starting on http://localhost:5000")
    print("\nAvailable endpoints:")
    print("- GET  /health               - Health check")
    print("- GET  /model/info           - Model information")
    print("- POST /train                - Train new model")
    print("- POST /predict/single       - Single prediction")
    print("- POST /predict/batch        - Batch predictions")
    print("- POST /predict/forecast     - Generate forecast")
    print("- GET  /api/docs             - API documentation")
    
    if not model_loaded:
        print("\n📋 To train a model:")
        print("1. Prepare your weather data CSV file with required columns")
        print("2. Use POST /train endpoint to upload and train")
        print("3. Or run: python improved_weather_model.py first")
    
    print("\n" + "=" * 40)
    
    app.run(host='0.0.0.0', port=5000, debug=True)