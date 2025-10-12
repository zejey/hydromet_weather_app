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

class SafetyTip(BaseModel):
    id: Optional[str] = None
    category_id: str
    description: str
    level: str
    order: int
    range: str
    color: str
    is_active: bool
    created_at: datetime = None
    updated_at: datetime = None

@router.post("/safety-tips", response_model=SafetyTip)
def create_safety_tip(tip: SafetyTip):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO safety_tips (category_id, description, level, order, range, color, is_active, created_at, updated_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            tip.category_id, tip.description, tip.level, tip.order, tip.range,
            tip.color, tip.is_active, tip.created_at, tip.updated_at
        ))
        conn.commit()
    return tip

@router.get("/safety-tips", response_model=List[SafetyTip])
def get_safety_tips():
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM safety_tips WHERE is_active = true ORDER BY 'order'")
        return cur.fetchall()

@router.get("/safety-tips/{tip_id}", response_model=SafetyTip)
def get_safety_tip(tip_id: str):
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM safety_tips WHERE id = %s", (tip_id,))
        result = cur.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Safety tip not found")
        return result

@router.put("/safety-tips/{tip_id}", response_model=SafetyTip)
def update_safety_tip(tip_id: str, tip: SafetyTip):
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE safety_tips SET category_id=%s, description=%s, level=%s, order=%s, range=%s, color=%s, is_active=%s, updated_at=%s WHERE id=%s
        """, (
            tip.category_id, tip.description, tip.level, tip.order, tip.range,
            tip.color, tip.is_active, tip.updated_at, tip_id
        ))
        conn.commit()
    return tip

@router.delete("/safety-tips/{tip_id}")
def delete_safety_tip(tip_id: str):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM safety_tips WHERE id = %s", (tip_id,))
        conn.commit()
    return {"message": "Safety tip deleted"}
