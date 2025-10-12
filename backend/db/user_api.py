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

class User(BaseModel):
    id: str
    first_name: str
    middle_name: Optional[str] = None
    last_name: str
    suffix: Optional[str] = None
    house_address: str
    barangay: str
    phone_number: str
    role: str
    is_verified: bool

@router.post("/users", response_model=User)
def create_user(user: User):
    now = datetime.now()
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO users (id, first_name, middle_name, last_name, suffix, house_address, barangay, phone_number, role, is_verified, created_at, updated_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id, first_name, middle_name, last_name, suffix, house_address, barangay, phone_number, role, is_verified, created_at, updated_at
        """, (
            user.id, user.first_name, user.middle_name, user.last_name, user.suffix,
            user.house_address, user.barangay, user.phone_number, user.role,
            user.is_verified, now, now
        ))
        new_user = cur.fetchone()
        conn.commit()
    return new_user

@router.get("/users", response_model=List[User])
def get_users():
    with conn.cursor() as cur: 
        cur.execute("SELECT * FROM users ORDER BY created_at DESC") 
        return cur.fetchall()

@router.get("/users/{user_id}", response_model=User)
def get_user(user_id: str):
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        result = cur.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="User not found")
        return result

@router.put("/users/{user_id}", response_model=User)
def update_user(user_id: str, user: User):
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE users SET first_name=%s, middle_name=%s, last_name=%s, suffix=%s, house_address=%s, barangay=%s, phone_number=%s, role=%s, is_verified=%s, updated_at=%s
            WHERE id=%s
        """, (
            user.first_name, user.middle_name, user.last_name, user.suffix,
            user.house_address, user.barangay, user.phone_number, user.role,
            user.is_verified, user.updated_at, user_id
        ))
        conn.commit()
    return user

@router.delete("/users/{user_id}")
def delete_user(user_id: str):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
        conn.commit()
    return {"message": "User deleted"}
