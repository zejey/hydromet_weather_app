import pandas as pd
import numpy as np
import os
import json
import joblib
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional, Union
import logging
from dataclasses import dataclass

from sklearn.model_selection import TimeSeriesSplit, cross_validate
from sklearn.ensemble import RandomForestClassifier, VotingClassifier
from sklearn.metrics import (
    accuracy_score, f1_score, roc_auc_score, confusion_matrix, 
    classification_report, precision_recall_fscore_support
)
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from xgboost import XGBClassifier
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import make_pipeline as make_imb_pipeline

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Custom exceptions
class WeatherDataError(Exception):
    """Custom exception for weather data related errors"""
    pass

class ModelTrainingError(Exception):
    """Custom exception for model training related errors"""
    pass

@dataclass
class ModelConfig:
    """Configuration class for model parameters"""
    # Model parameters
    rf_n_estimators: int = 100
    rf_max_depth: int = 15
    rf_min_samples_split: int = 5
    rf_min_samples_leaf: int = 2
    
    xgb_n_estimators: int = 100
    xgb_max_depth: int = 6
    xgb_learning_rate: float = 0.1
    xgb_subsample: float = 0.8
    xgb_colsample_bytree: float = 0.8
    
    # Feature engineering parameters
    daily_lags: List[int] = None
    hourly_lags: List[int] = None
    cv_splits: int = 5
    test_size: float = 0.2
    min_training_samples: int = 50
    smote_k_neighbors: int = 3
    
    # Hazard scoring thresholds
    precipitation_thresholds: List[float] = None
    wind_thresholds: List[float] = None
    pressure_change_thresholds: List[float] = None
    temperature_thresholds: Dict[str, List[float]] = None
    
    def __post_init__(self):
        """Set default values for lists and dicts"""
        if self.daily_lags is None:
            self.daily_lags = [1, 3, 7]
        if self.hourly_lags is None:
            self.hourly_lags = [1, 3, 6, 12]
        if self.precipitation_thresholds is None:
            self.precipitation_thresholds = [2.5, 10, 25, 50]
        if self.wind_thresholds is None:
            self.wind_thresholds = [15, 20, 30, 40]
        if self.pressure_change_thresholds is None:
            self.pressure_change_thresholds = [-2, -5, -10]
        if self.temperature_thresholds is None:
            self.temperature_thresholds = {
                'extreme_high': [32, 35, 40],
                'extreme_low': [5, 0, -5, -10],
                'temp_range': [15, 20, 25]
            }

class FeatureEngineer:
    """Separate class for feature engineering operations"""
    
    def __init__(self, config: ModelConfig):
        self.config = config
        
    @staticmethod
    def calculate_dew_point(temp: float, humidity: float) -> float:
        """
        Calculate dew point using Magnus formula
        
        Args:
            temp: Temperature in Celsius
            humidity: Relative humidity as percentage (0-100)
            
        Returns:
            Dew point in Celsius, or NaN if inputs invalid
        """
        try:
            temp = float(temp)
            humidity = float(humidity)
            if humidity <= 0 or humidity > 100:
                return np.nan
        except (ValueError, TypeError):
            return np.nan
            
        a = 17.27
        b = 237.7
        alpha = ((a * temp) / (b + temp)) + np.log(humidity / 100.0)
        return (b * alpha) / (a - alpha)
    
    def create_lag_features(self, df: pd.DataFrame, lags: List[int], 
                           lag_suffix: str = 'h') -> pd.DataFrame:
        """
        Create lagged features for time series modeling
        
        Args:
            df: Input DataFrame with time series data
            lags: List of lag periods to create
            lag_suffix: Suffix for lag feature names ('h' for hours, 'd' for days)
            
        Returns:
            DataFrame with added lag features
        """
        logger.debug(f"Creating lag features with lags: {lags}")
        df = df.sort_values('timestamp').copy()
        
        # Define features to lag based on available columns
        lag_features = []
        potential_features = ['temperature', 'humidity', 'wind_speed', 'pressure', 
                            'rain', 'precipitation', 'temp_min', 'temp_max']
        
        for feature in potential_features:
            if feature in df.columns:
                lag_features.append(feature)
        
        logger.debug(f"Creating lags for features: {lag_features}")
        
        for feature in lag_features:
            for lag in lags:
                lag_col_name = f'{feature}_lag_{lag}{lag_suffix}'
                df[lag_col_name] = df[feature].shift(lag)
        
        return df
    
    def create_trend_features(self, df: pd.DataFrame, is_daily: bool = True) -> pd.DataFrame:
        """
        Create trend and change features
        
        Args:
            df: Input DataFrame
            is_daily: Whether data is daily (True) or hourly (False)
            
        Returns:
            DataFrame with added trend features
        """
        logger.debug(f"Creating trend features (daily: {is_daily})")
        df = df.sort_values('timestamp').copy()
        
        suffix = 'd' if is_daily else 'h'
        window_sizes = [1, 3, 7] if is_daily else [1, 3, 6]
        
        # Pressure trends (critical for weather prediction)
        if 'pressure' in df.columns:
            df[f'pressure_change_1{suffix}'] = df['pressure'].diff(1)
            df[f'pressure_change_3{suffix}'] = df['pressure'].diff(3)
            
            trend_window = 7 if is_daily else 6
            df[f'pressure_trend_{trend_window}{suffix}'] = df['pressure'].rolling(
                trend_window, min_periods=3
            ).apply(
                lambda x: np.polyfit(range(len(x)), x, 1)[0] if len(x) >= 3 else np.nan
            )
        
        # Temperature trends
        if 'temperature' in df.columns:
            df[f'temp_change_1{suffix}'] = df['temperature'].diff(1)
            
            temp_trend_window = 3 if is_daily else 3
            df[f'temp_trend_{temp_trend_window}{suffix}'] = df['temperature'].rolling(
                temp_trend_window, min_periods=2
            ).apply(
                lambda x: np.polyfit(range(len(x)), x, 1)[0] if len(x) >= 2 else np.nan
            )
            
            variability_window = 7 if is_daily else 6
            df[f'temp_variability_{variability_window}{suffix}'] = df['temperature'].rolling(
                variability_window, min_periods=3
            ).std()
        
        # Wind patterns
        wind_col = 'wind_speed'
        if wind_col in df.columns:
            df[f'wind_change_1{suffix}'] = df[wind_col].diff(1)
            df[f'wind_max_3{suffix}'] = df[wind_col].rolling(3, min_periods=1).max()
            df[f'wind_variability_{window_sizes[-1]}{suffix}'] = df[wind_col].rolling(
                window_sizes[-1], min_periods=3
            ).std()
        
        # Precipitation patterns (for daily data) - FIXED VERSION
        if is_daily and 'precipitation' in df.columns:
            df['precip_sum_3d'] = df['precipitation'].rolling(3, min_periods=1).sum()
            df['precip_sum_7d'] = df['precipitation'].rolling(7, min_periods=1).sum()
            
            # FIX: Correctly count dry days in rolling window
            def count_dry_days(x):
                """Count number of days with zero precipitation in the window"""
                return (x == 0).sum()
            
            df['dry_days_7d'] = df['precipitation'].rolling(7, min_periods=1).apply(count_dry_days)
        
        return df
    
    def create_derived_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Create meteorologically meaningful derived features
        
        Args:
            df: Input DataFrame
            
        Returns:
            DataFrame with added derived features
        """
        logger.debug("Creating derived features")
        
        # Temperature range (if min/max available)
        if all(col in df.columns for col in ['temp_max', 'temp_min']):
            df['temp_range'] = df['temp_max'] - df['temp_min']
        
        # Estimate humidity from temperature and precipitation (rough approximation)
        if 'precipitation' in df.columns and 'temperature' in df.columns:
            df['humidity_est'] = np.clip(
                60 + (df['precipitation'] * 10) - (df['temperature'] - 20) * 2,
                0, 100
            )
            
            # Calculate estimated dew point
            df['dew_point_est'] = df.apply(
                lambda row: self.calculate_dew_point(row['temperature'], row['humidity_est']),
                axis=1
            )
        
        # Wind chill (for temperatures below 10°C)
        if all(col in df.columns for col in ['temperature', 'wind_speed']):
            wind_chill_mask = df['temperature'] < 10
            df['wind_chill'] = np.where(
                wind_chill_mask & (df['wind_speed'] > 0),
                13.12 + 0.6215 * df['temperature'] - 11.37 * (df['wind_speed'] ** 0.16) + 
                0.3965 * df['temperature'] * (df['wind_speed'] ** 0.16),
                df['temperature']
            )
        
        # Heat index approximation
        if 'humidity_est' in df.columns and 'temperature' in df.columns:
            df['heat_index'] = np.where(
                df['temperature'] > 25,
                df['temperature'] + 0.5 * (df['humidity_est'] - 10),
                df['temperature']
            )
        
        return df
    
    def create_categorical_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Create categorical features based on weather thresholds
        
        Args:
            df: Input DataFrame
            
        Returns:
            DataFrame with added categorical features
        """
        logger.debug("Creating categorical features")
        
        # Precipitation intensity categories
        if 'precipitation' in df.columns:
            precip_bins = [-0.1] + self.config.precipitation_thresholds + [np.inf]
            df['precip_category'] = pd.cut(
                df['precipitation'], 
                bins=precip_bins,
                labels=list(range(len(precip_bins) - 1))
            ).astype(float)
        
        # Wind categories (Beaufort scale approximation)
        if 'wind_speed' in df.columns:
            wind_bins = [0] + self.config.wind_thresholds + [np.inf]
            df['wind_category'] = pd.cut(
                df['wind_speed'],
                bins=wind_bins,
                labels=list(range(len(wind_bins) - 1))
            ).astype(float)
        
        # Pressure categories (relative to standard)
        if 'pressure' in df.columns:
            df['pressure_category'] = pd.cut(
                df['pressure'],
                bins=[0, 1000, 1013, 1020, np.inf],
                labels=[0, 1, 2, 3]
            ).astype(float)
        
        return df

class HazardScorer:
    """Separate class for hazard level scoring logic"""
    
    def __init__(self, config: ModelConfig):
        self.config = config
        
    def estimate_hazard_level_csv(self, row: pd.Series) -> int:
        """
        Estimate hazard level for CSV data format
        
        Args:
            row: Pandas Series with weather data
            
        Returns:
            Hazard level (0-4)
        """
        try:
            # Extract values with defaults
            precip = float(row.get('precipitation', 0))
            wind = float(row.get('wind_speed', 0))
            wind_gust = float(row.get('wind_gust', wind))
            pressure_change = float(row.get('pressure_change_3d', 0))
            temp = float(row.get('temperature', 20))
            temp_max = float(row.get('temp_max', temp))
            temp_min = float(row.get('temp_min', temp))
            temp_range = float(row.get('temp_range', 0))
        except (ValueError, TypeError) as e:
            logger.warning(f"Error extracting values for hazard scoring: {e}")
            return 0
        
        hazard_score = 0
        
        # Precipitation contribution
        for i, threshold in enumerate(reversed(self.config.precipitation_thresholds)):
            if precip >= threshold:
                hazard_score += len(self.config.precipitation_thresholds) - i
                break
        
        # Wind contribution (using gust if available, otherwise sustained wind)
        wind_to_check = max(wind, wind_gust)
        for i, threshold in enumerate(reversed(self.config.wind_thresholds)):
            if wind_to_check >= threshold:
                hazard_score += len(self.config.wind_thresholds) - i
                break
        
        # Pressure change contribution (rapid drops indicate storms)
        for i, threshold in enumerate(self.config.pressure_change_thresholds):
            if pressure_change <= threshold:
                hazard_score += len(self.config.pressure_change_thresholds) - i
                break
        
        # Extreme temperature contribution
        temp_thresholds = self.config.temperature_thresholds
        
        # High temperature scoring
        for i, threshold in enumerate(reversed(temp_thresholds['extreme_high'])):
            if temp_max >= threshold:
                hazard_score += len(temp_thresholds['extreme_high']) - i
                break
        
        # Low temperature scoring
        for i, threshold in enumerate(temp_thresholds['extreme_low']):
            if temp_min <= threshold:
                hazard_score += len(temp_thresholds['extreme_low']) - i
                break
        
        # Large temperature swings
        for i, threshold in enumerate(reversed(temp_thresholds['temp_range'])):
            if temp_range >= threshold:
                hazard_score += len(temp_thresholds['temp_range']) - i
                break
        
        # Cap at maximum level and ensure minimum is 0
        return max(0, min(hazard_score, 4))

class ImprovedWeatherForecaster:
    """
    Enhanced weather forecasting model with improved modularity and configuration
    """
    
    def __init__(self, config: Optional[ModelConfig] = None):
        """
        Initialize the weather forecaster
        
        Args:
            config: Model configuration. If None, uses default configuration.
        """
        self.config = config or ModelConfig()
        self.model_version = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.models_dir = "models"
        os.makedirs(self.models_dir, exist_ok=True)
        
        self.target_column = "hazard_level"
        
        # Initialize helper classes
        self.feature_engineer = FeatureEngineer(self.config)
        self.hazard_scorer = HazardScorer(self.config)
        
        # CSV column mapping
        self.csv_column_mapping = {
            'date': 'timestamp',
            'tavg': 'temperature',
            'tmin': 'temp_min',
            'tmax': 'temp_max',
            'prcp': 'precipitation',
            'snow': 'snowfall',
            'wdir': 'wind_direction',
            'wspd': 'wind_speed',
            'wpgt': 'wind_gust',
            'pres': 'pressure',
            'tsun': 'sunshine_duration'
        }
        
        self.base_features = [
            'temperature', 'temp_min', 'temp_max', 'wind_speed', 'pressure',
            'precipitation', 'wind_direction', 'wind_gust', 'day_of_year', 'month'
        ]
        
        logger.info(f"ImprovedWeatherForecaster initialized with version {self.model_version}")
    
    def validate_csv_data(self, df: pd.DataFrame) -> None:
        """
        Validate input CSV data
        
        Args:
            df: Input DataFrame to validate
            
        Raises:
            WeatherDataError: If data validation fails
        """
        if df.empty:
            raise WeatherDataError("Input DataFrame is empty")
        
        # Check for required columns after mapping
        required_columns = ['date', 'tavg']  # Minimum required
        original_columns = set(df.columns)
        
        missing_required = []
        for col in required_columns:
            if col not in original_columns:
                missing_required.append(col)
        
        if missing_required:
            raise WeatherDataError(
                f"Missing required columns: {missing_required}. "
                f"Available columns: {list(original_columns)}"
            )
        
        # Check data types and ranges
        if 'date' in df.columns:
            try:
                pd.to_datetime(df['date'].iloc[0])
            except (ValueError, TypeError):
                raise WeatherDataError("Date column contains invalid date format")
        
        logger.info(f"Data validation passed for {len(df)} records")
    
    def load_csv_data(self, csv_path: str) -> pd.DataFrame:
        """
        Load weather data from CSV file with validation
        
        Args:
            csv_path: Path to CSV file
            
        Returns:
            Loaded DataFrame
            
        Raises:
            WeatherDataError: If file cannot be loaded or is invalid
        """
        if not os.path.exists(csv_path):
            raise WeatherDataError(f"CSV file not found: {csv_path}")
        
        try:
            df = pd.read_csv(csv_path)
            logger.info(f"Loaded {len(df)} records from {csv_path}")
            
            # Validate the loaded data
            self.validate_csv_data(df)
            
            return df
        except pd.errors.EmptyDataError:
            raise WeatherDataError(f"CSV file is empty: {csv_path}")
        except pd.errors.ParserError as e:
            raise WeatherDataError(f"Error parsing CSV file {csv_path}: {e}")
        except Exception as e:
            raise WeatherDataError(f"Error loading CSV: {e}")
    
    def preprocess_csv_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Enhanced preprocessing for CSV data format
        
        Args:
            df: Input DataFrame
            
        Returns:
            Preprocessed DataFrame
            
        Raises:
            WeatherDataError: If preprocessing fails
        """
        logger.info("Starting data preprocessing")
        
        try:
            # Rename columns according to mapping
            df = df.rename(columns=self.csv_column_mapping)
            
            # Convert timestamp
            df['timestamp'] = pd.to_datetime(df['timestamp'], errors='coerce')
            
            # Remove rows with invalid timestamps
            initial_count = len(df)
            df = df.dropna(subset=['timestamp'])
            if len(df) < initial_count:
                logger.warning(f"Dropped {initial_count - len(df)} rows with invalid timestamps")
            
            df = df.sort_values('timestamp').copy()
            
            # Handle missing values and ensure numeric conversion
            numeric_cols = ['temperature', 'temp_min', 'temp_max', 'precipitation', 
                           'wind_speed', 'wind_gust', 'pressure', 'wind_direction']
            
            for col in numeric_cols:
                if col in df.columns:
                    df[col] = pd.to_numeric(df[col], errors='coerce')
            
            # Fill missing values with appropriate defaults
            self._fill_missing_values(df)
            
            # Create time-based features
            self._create_time_features(df)
            
            # Create derived meteorological features
            df = self.feature_engineer.create_derived_features(df)
            
            # Create categorical features
            df = self.feature_engineer.create_categorical_features(df)
            
            # Create lag features (adapted for daily data)
            df = self.feature_engineer.create_lag_features(df, self.config.daily_lags, 'd')
            
            # Create trend features (adapted for daily data)
            df = self.feature_engineer.create_trend_features(df, is_daily=True)
            
            # Create target variable
            logger.info("Calculating hazard levels")
            df[self.target_column] = df.apply(self.hazard_scorer.estimate_hazard_level_csv, axis=1)
            
            # Remove rows with too many NaN values
            initial_count = len(df)
            df = df.dropna(thresh=len(df.columns) * 0.6)
            if len(df) < initial_count:
                logger.info(f"Dropped {initial_count - len(df)} rows with excessive missing values")
            
            logger.info(f"Preprocessing completed. Final dataset: {len(df)} records")
            
            return df
            
        except Exception as e:
            logger.error(f"Error in preprocessing: {e}")
            raise WeatherDataError(f"Preprocessing failed: {e}")
    
    def _fill_missing_values(self, df: pd.DataFrame) -> None:
        """Fill missing values with appropriate defaults"""
        df['precipitation'] = df['precipitation'].fillna(0)
        
        if 'snowfall' in df.columns:
            df['snowfall'] = df['snowfall'].fillna(0)
        else:
            df['snowfall'] = 0
            
        if 'wind_gust' in df.columns:
            df['wind_gust'] = df['wind_gust'].fillna(df['wind_speed'])
        else:
            df['wind_gust'] = df.get('wind_speed', 0)
            
        if 'wind_direction' in df.columns:
            df['wind_direction'] = df['wind_direction'].fillna(df['wind_direction'].median())
        else:
            df['wind_direction'] = 180
    
    def _create_time_features(self, df: pd.DataFrame) -> None:
        """Create time-based features"""
        df['day_of_year'] = df['timestamp'].dt.dayofyear
        df['month'] = df['timestamp'].dt.month
        df['season'] = ((df['month'] % 12 + 3) // 3).astype(int)
        df['is_weekend'] = (df['timestamp'].dt.weekday >= 5).astype(int)
    
    def create_ensemble_pipeline(self) -> Pipeline:
        """
        Create an ensemble model pipeline with configured parameters
        
        Returns:
            Configured pipeline
        """
        logger.info("Creating ensemble pipeline")
        
        # Individual models with configuration
        rf_model = RandomForestClassifier(
            n_estimators=self.config.rf_n_estimators,
            max_depth=self.config.rf_max_depth,
            min_samples_split=self.config.rf_min_samples_split,
            min_samples_leaf=self.config.rf_min_samples_leaf,
            random_state=42,
            class_weight='balanced'
        )
        
        xgb_model = XGBClassifier(
            n_estimators=self.config.xgb_n_estimators,
            max_depth=self.config.xgb_max_depth,
            learning_rate=self.config.xgb_learning_rate,
            subsample=self.config.xgb_subsample,
            colsample_bytree=self.config.xgb_colsample_bytree,
            random_state=42,
            eval_metric='mlogloss'
        )
        
        # Create voting ensemble
        ensemble = VotingClassifier(
            estimators=[
                ('rf', rf_model),
                ('xgb', xgb_model)
            ],
            voting='soft'  # Use predicted probabilities
        )
        
        # Create pipeline with preprocessing
        pipeline = make_imb_pipeline(
            StandardScaler(),
            SMOTE(random_state=42, k_neighbors=self.config.smote_k_neighbors),
            ensemble
        )
        
        return pipeline
    
    def time_series_cross_validate(self, X: pd.DataFrame, y: pd.Series, 
                                 n_splits: Optional[int] = None) -> Dict:
        """
        Perform time-series aware cross-validation
        
        Args:
            X: Feature matrix
            y: Target vector
            n_splits: Number of CV splits. If None, uses config value.
            
        Returns:
            Dictionary with cross-validation results
        """
        if n_splits is None:
            n_splits = self.config.cv_splits
            
        logger.info(f"Performing time-series cross-validation with {n_splits} splits")
        
        tscv = TimeSeriesSplit(n_splits=n_splits)
        pipeline = self.create_ensemble_pipeline()
        
        scoring = ['accuracy', 'f1_weighted', 'roc_auc_ovr']
        
        try:
            cv_results = cross_validate(
                pipeline, X, y, cv=tscv, scoring=scoring,
                return_train_score=True, n_jobs=-1
            )
            
            return {
                'cv_accuracy_mean': cv_results['test_accuracy'].mean(),
                'cv_accuracy_std': cv_results['test_accuracy'].std(),
                'cv_f1_mean': cv_results['test_f1_weighted'].mean(),
                'cv_f1_std': cv_results['test_f1_weighted'].std(),
                'cv_roc_auc_mean': cv_results['test_roc_auc_ovr'].mean(),
                'cv_roc_auc_std': cv_results['test_roc_auc_ovr'].std(),
            }
        except Exception as e:
            logger.warning(f"Cross-validation failed: {e}")
            return {
                'cv_accuracy_mean': np.nan,
                'cv_accuracy_std': np.nan,
                'cv_f1_mean': np.nan,
                'cv_f1_std': np.nan,
                'cv_roc_auc_mean': np.nan,
                'cv_roc_auc_std': np.nan,
            }
    
    def evaluate_temporal_performance(self, model, X_test: pd.DataFrame, y_test: pd.Series, 
                                    timestamps_test: pd.Series) -> Dict:
        """
        Evaluate model performance across different time horizons
        
        Args:
            model: Trained model
            X_test: Test features
            y_test: Test targets
            timestamps_test: Test timestamps
            
        Returns:
            Dictionary with temporal performance metrics
        """
        logger.info("Evaluating temporal performance")
        
        results = {}
        
        # Overall performance
        y_pred = model.predict(X_test)
        y_pred_proba = model.predict_proba(X_test)
        
        results['overall'] = {
            'accuracy': accuracy_score(y_test, y_pred),
            'f1_weighted': f1_score(y_test, y_pred, average='weighted'),
        }
        
        # Add ROC AUC if possible
        try:
            results['overall']['roc_auc'] = roc_auc_score(y_test, y_pred_proba, multi_class='ovr')
        except ValueError as e:
            logger.warning(f"Cannot compute ROC AUC: {e}")
            results['overall']['roc_auc'] = np.nan
        
        # Performance by month
        try:
            test_df = pd.DataFrame({
                'timestamp': timestamps_test,
                'y_true': y_test,
                'y_pred': y_pred
            })
            test_df['month'] = test_df['timestamp'].dt.month
            
            monthly_accuracy = []
            for month in range(1, 13):
                month_mask = test_df['month'] == month
                if month_mask.sum() > 0:
                    month_acc = accuracy_score(
                        test_df.loc[month_mask, 'y_true'],
                        test_df.loc[month_mask, 'y_pred']
                    )
                    monthly_accuracy.append(month_acc)
            
            if monthly_accuracy:
                results['monthly_performance'] = {
                    'mean_accuracy': np.mean(monthly_accuracy),
                    'std_accuracy': np.std(monthly_accuracy),
                    'best_month': np.argmax(monthly_accuracy) + 1,
                    'worst_month': np.argmin(monthly_accuracy) + 1
                }
        except Exception as e:
            logger.warning(f"Could not compute monthly performance: {e}")
            results['monthly_performance'] = {}
        
        return results
    
    def train_model_from_csv(self, csv_path: str) -> Dict:
        """
        Train the improved weather forecasting model from CSV file
        
        Args:
            csv_path: Path to CSV file containing training data
            
        Returns:
            Dictionary with training results
            
        Raises:
            ModelTrainingError: If training fails
        """
        logger.info(f"Training model from CSV: {csv_path}")
        
        try:
            # Load and preprocess data
            raw_data = self.load_csv_data(csv_path)
            processed_data = self.preprocess_csv_data(raw_data)
            
            if processed_data.empty:
                raise ModelTrainingError("No training data available after preprocessing")
            
            logger.info(f"Processed {len(processed_data)} records")
            
            # Check class distribution
            class_counts = processed_data[self.target_column].value_counts().sort_index()
            logger.info(f"Class distribution: {class_counts.to_dict()}")
            
            # Prepare features and target
            feature_columns = self._get_feature_columns(processed_data)
            
            X = processed_data[feature_columns].fillna(0)
            y = processed_data[self.target_column]
            timestamps = processed_data['timestamp']
            
            logger.info(f"Using {len(feature_columns)} features")
            logger.info(f"Feature examples: {feature_columns[:10]}")
            
            # Time-series aware train-test split
            split_idx = int(len(X) * (1 - self.config.test_size))
            X_train, X_test = X.iloc[:split_idx], X.iloc[split_idx:]
            y_train, y_test = y.iloc[:split_idx], y.iloc[split_idx:]
            timestamps_test = timestamps.iloc[split_idx:]
            
            # Check if we have enough samples for cross-validation
            cv_results = {}
            if len(X_train) >= self.config.min_training_samples:
                logger.info("Performing cross-validation...")
                cv_results = self.time_series_cross_validate(X_train, y_train)
            else:
                logger.warning("Limited training data. Skipping cross-validation.")
                cv_results = {
                    'cv_accuracy_mean': np.nan,
                    'cv_accuracy_std': np.nan,
                    'cv_f1_mean': np.nan,
                    'cv_f1_std': np.nan,
                    'cv_roc_auc_mean': np.nan,
                    'cv_roc_auc_std': np.nan,
                }
            
            # Train final model
            logger.info("Training final model...")
            pipeline = self.create_ensemble_pipeline()
            pipeline.fit(X_train, y_train)
            
            # Evaluate on test set
            temporal_results = self.evaluate_temporal_performance(
                pipeline, X_test, y_test, timestamps_test
            )
            
            # Additional metrics
            y_pred = pipeline.predict(X_test)
            y_pred_proba = pipeline.predict_proba(X_test)
            
            # Handle case where some classes might be missing in test set
            try:
                test_roc_auc = roc_auc_score(y_test, y_pred_proba, multi_class='ovr')
            except ValueError:
                logger.warning("Cannot compute ROC AUC - insufficient class representation")
                test_roc_auc = np.nan
            
            metrics = {
                'test_accuracy': accuracy_score(y_test, y_pred),
                'test_f1_weighted': f1_score(y_test, y_pred, average='weighted'),
                'test_roc_auc': test_roc_auc,
                'confusion_matrix': confusion_matrix(y_test, y_pred).tolist(),
                'classification_report': classification_report(y_test, y_pred, output_dict=True),
                'cross_validation': cv_results,
                'temporal_performance': temporal_results,
                'num_records': len(processed_data),
                'features_used': feature_columns,
                'class_distribution': class_counts.to_dict(),
                'date_range': {
                    'start': processed_data['timestamp'].min().isoformat(),
                    'end': processed_data['timestamp'].max().isoformat()
                }
            }
            
            # Save model
            model_path = self.save_model(pipeline, metrics)
            
            logger.info("Model training completed successfully")
            
            return {
                'status': 'success',
                'model': 'Ensemble (RandomForest + XGBoost)',
                'version': self.model_version,
                'metrics': metrics,
                'model_path': model_path,
                'training_samples': len(processed_data)
            }
            
        except (WeatherDataError, ModelTrainingError):
            raise
        except Exception as e:
            logger.error(f"Unexpected error in model training: {e}")
            raise ModelTrainingError(f"Training failed: {e}")
    
    def _get_feature_columns(self, df: pd.DataFrame) -> List[str]:
        """
        Get list of feature columns for model training
        
        Args:
            df: Processed DataFrame
            
        Returns:
            List of feature column names
        """
        exclude_columns = {self.target_column, 'timestamp'}
        exclude_patterns = {'_category'}  # Exclude categorical columns that might cause issues
        
        feature_columns = []
        for col in df.columns:
            if col not in exclude_columns and not any(pattern in col for pattern in exclude_patterns):
                feature_columns.append(col)
        
        return feature_columns
    
    def save_model(self, model, metrics: Dict) -> str:
        """
        Save the trained model and metadata
        
        Args:
            model: Trained model pipeline
            metrics: Model performance metrics
            
        Returns:
            Path to saved model file
        """
        model_filename = f"{self.models_dir}/improved_weather_model_v{self.model_version}.pkl"
        metadata = {
            'model_type': 'Ensemble (RandomForest + XGBoost)',
            'version': self.model_version,
            'training_date': datetime.now().isoformat(),
            'metrics': metrics,
            'target': self.target_column,
            'config': {
                'rf_n_estimators': self.config.rf_n_estimators,
                'xgb_n_estimators': self.config.xgb_n_estimators,
                'daily_lags': self.config.daily_lags,
                'test_size': self.config.test_size
            }
        }
        
        try:
            joblib.dump(model, model_filename)
            
            with open(f"{self.models_dir}/metadata_v{self.model_version}.json", 'w') as f:
                json.dump(metadata, f, indent=2, default=str)
            
            # Create latest link
            latest_link = f"{self.models_dir}/improved_weather_model_latest.pkl"
            if os.path.exists(latest_link):
                os.remove(latest_link)
            
            # Use relative path for symlink
            rel_path = os.path.basename(model_filename)
            os.symlink(rel_path, latest_link)
            
            logger.info(f"Model saved to {model_filename}")
            return model_filename
            
        except Exception as e:
            logger.error(f"Error saving model: {e}")
            raise ModelTrainingError(f"Failed to save model: {e}")
    
    def predict_from_csv(self, model_path: str, csv_path: str) -> Dict:
        """
        Make predictions using the trained model on CSV data
        
        Args:
            model_path: Path to saved model file
            csv_path: Path to CSV file with data for prediction
            
        Returns:
            Dictionary with predictions and metadata
            
        Raises:
            WeatherDataError: If data loading/processing fails
            ModelTrainingError: If model loading fails
        """
        logger.info(f"Making predictions from CSV: {csv_path}")
        
        try:
            # Load model
            if not os.path.exists(model_path):
                raise ModelTrainingError(f"Model file not found: {model_path}")
            
            model = joblib.load(model_path)
            logger.info(f"Model loaded from {model_path}")
            
            # Load and preprocess new data
            raw_data = self.load_csv_data(csv_path)
            processed_data = self.preprocess_csv_data(raw_data)
            
            if processed_data.empty:
                raise WeatherDataError("No data available for prediction after preprocessing")
            
            # Prepare features
            feature_columns = self._get_feature_columns(processed_data)
            X = processed_data[feature_columns].fillna(0)
            
            # Make predictions
            predictions = model.predict(X)
            probabilities = model.predict_proba(X)
            
            logger.info(f"Generated {len(predictions)} predictions")
            
            return {
                'predictions': predictions.tolist(),
                'probabilities': probabilities.tolist(),
                'timestamps': processed_data['timestamp'].dt.strftime('%Y-%m-%d').tolist(),
                'hazard_levels': ['No Risk', 'Low Risk', 'Moderate Risk', 'High Risk', 'Extreme Risk'],
                'num_predictions': len(predictions)
            }
            
        except (WeatherDataError, ModelTrainingError):
            raise
        except Exception as e:
            logger.error(f"Unexpected error in prediction: {e}")
            raise ModelTrainingError(f"Prediction failed: {e}")

# Example usage and testing
if __name__ == "__main__":
    # Configure logging for demo
    logging.basicConfig(level=logging.INFO)
    
    # Create forecaster with custom configuration
    config = ModelConfig()
    config.rf_n_estimators = 50  # Reduce for faster demo
    config.xgb_n_estimators = 50
    
    forecaster = ImprovedWeatherForecaster(config)
    
    # Train model from CSV file
    csv_file_path = "export.csv"  # Updated to use your export.csv file
    
    try:
        result = forecaster.train_model_from_csv(csv_file_path)
        
        if result['status'] == 'success':
            logger.info(f"Training successful. Model saved to {result['model_path']}")
            logger.info(f"Test Accuracy: {result['metrics']['test_accuracy']:.3f}")
            logger.info(f"Test F1 Score: {result['metrics']['test_f1_weighted']:.3f}")
            
            if not np.isnan(result['metrics']['test_roc_auc']):
                logger.info(f"Test ROC AUC: {result['metrics']['test_roc_auc']:.3f}")
            
            cv_metrics = result['metrics']['cross_validation']
            if not np.isnan(cv_metrics['cv_accuracy_mean']):
                logger.info(f"CV Accuracy: {cv_metrics['cv_accuracy_mean']:.3f} ± {cv_metrics['cv_accuracy_std']:.3f}")
            
            logger.info(f"Date range: {result['metrics']['date_range']['start']} to {result['metrics']['date_range']['end']}")
            logger.info(f"Class distribution: {result['metrics']['class_distribution']}")
            
            # Example prediction on the same CSV (you can use a different CSV for new predictions)
            try:
                predictions = forecaster.predict_from_csv(result['model_path'], csv_file_path)
                logger.info(f"Made {predictions['num_predictions']} predictions")
            except Exception as pred_error:
                logger.error(f"Prediction failed: {pred_error}")
        
        else:
            logger.error("Training failed.")
            
    except (WeatherDataError, ModelTrainingError) as e:
        logger.error(f"Error: {e}")
    except FileNotFoundError:
        logger.error(f"CSV file not found: {csv_file_path}")
        logger.info("Please ensure you have a CSV file with weather data to train the model.")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")