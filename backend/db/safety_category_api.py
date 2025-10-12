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

class SafetyCategory(BaseModel):
    category_id: str
    name: str
    description: Optional[str] = None
    order_num: Optional[int] = None
    icon: Optional[str] = None
    gradient_colors: Optional[str] = None
    created_at: datetime = None
    updated_at: datetime = None
    is_active: Optional[bool] = True

@router.post("/categories", response_model=SafetyCategory)
def create_category(category: SafetyCategory):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO safety_categories (category_id, name, description, order_num, icon, gradient_colors, created_at, updated_at, is_active)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            category.category_id, category.name, category.description, category.order_num,
            category.icon, category.gradient_colors, category.created_at, category.updated_at,
            category.is_active
        ))
        conn.commit()
    return category

@router.get("/categories", response_model=List[SafetyCategory])
def get_categories():
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM safety_categories WHERE is_active = true ORDER BY order_num")
        return cur.fetchall()

@router.get("/categories/{cat_id}", response_model=SafetyCategory)
def get_category(cat_id: str):
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM safety_categories WHERE category_id = %s", (cat_id,))
        result = cur.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Category not found")
        return result

@router.put("/categories/{cat_id}", response_model=SafetyCategory)
def update_category(cat_id: str, category: SafetyCategory):
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE safety_categories SET name=%s, description=%s, order_num=%s, icon=%s, gradient_colors=%s, updated_at=%s, is_active=%s WHERE category_id=%s
        """, (
            category.name, category.description, category.order_num,
            category.icon, category.gradient_colors, category.updated_at, category.is_active,
            cat_id
        ))
        conn.commit()
    return category

@router.delete("/categories/{cat_id}")
def delete_category(cat_id: str):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM safety_categories WHERE category_id = %s", (cat_id,))
        conn.commit()
    return {"message": "Category deleted"}
