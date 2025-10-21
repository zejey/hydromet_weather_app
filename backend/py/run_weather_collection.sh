#!/bin/bash

# Activate venv and run collection
cd /home/zj/Workspace/hydromet_weather_app/backend/py
source /home/zj/Workspace/hydromet_weather_app/venv/bin/activate
python data_pipeline_24h.py --collect