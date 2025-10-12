from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from dotenv import load_dotenv
from datetime import datetime

router = APIRouter()

load_dotenv()
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")

# Database connection settings (update with your credentials)
conn = psycopg2.connect(
    dbname=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD,
    host=DB_HOST,
    port=DB_PORT,
    cursor_factory=RealDictCursor
)

class EmergencyHotline(BaseModel):
    id: str
    service_name: str
    phone_number: str
    category: str
    icon_color: str
    icon_type: str
    is_active: bool
    priority: int
    created_at: datetime 
    updated_at: datetime

@router.post("/hotlines", response_model=EmergencyHotline)
def create_hotline(hotline: EmergencyHotline):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO emergency_hotlines (id, service_name, phone_number, category, icon_color, icon_type, is_active, priority, created_at, updated_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            hotline.id, hotline.service_name, hotline.phone_number, hotline.category,
            hotline.icon_color, hotline.icon_type, hotline.is_active, hotline.priority,
            hotline.created_at, hotline.updated_at
        ))
        conn.commit()
    return hotline

@router.get("/hotlines", response_model=List[EmergencyHotline])
def get_hotlines():
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM emergency_hotlines WHERE is_active = true ORDER BY priority")
        return cur.fetchall()

@router.get("/hotlines/{hotline_id}", response_model=EmergencyHotline)
def get_hotline(hotline_id: str):
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM emergency_hotlines WHERE id = %s", (hotline_id,))
        result = cur.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Hotline not found")
        return result

@router.put("/hotlines/{hotline_id}", response_model=EmergencyHotline)
def update_hotline(hotline_id: str, hotline: EmergencyHotline):
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE emergency_hotlines SET service_name=%s, phone_number=%s, category=%s, icon_color=%s, icon_type=%s, is_active=%s, priority=%s, updated_at=%s WHERE id=%s
        """, (
            hotline.service_name, hotline.phone_number, hotline.category, hotline.icon_color,
            hotline.icon_type, hotline.is_active, hotline.priority, hotline.updated_at,
            hotline_id
        ))
        conn.commit()
    return hotline

@router.delete("/hotlines/{hotline_id}")
def delete_hotline(hotline_id: str):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM emergency_hotlines WHERE id = %s", (hotline_id,))
        conn.commit()
    return {"message": "Hotline deleted"}
