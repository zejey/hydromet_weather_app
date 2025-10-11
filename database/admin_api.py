from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from dotenv import load_dotenv

router = APIRouter()

load_dotenv()
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")

conn = psycopg2.connect(
    dbname=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD,
    host=DB_HOST,
    port=DB_PORT,
    cursor_factory=RealDictCursor
)

class Admin(BaseModel):
    id: int
    email: str
    role: str
    username: str
    uid: str

@router.post("/admins", response_model=Admin)
def create_admin(admin: Admin):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO admin (email, role, username, uid)
            VALUES (%s, %s, %s, %s)
            RETURNING id, email, role, username, uid
        """, (admin.email, admin.role, admin.username, admin.uid))
        new_admin = cur.fetchone()
        conn.commit()
    return new_admin

@router.get("/admins", response_model=List[Admin])
def get_admins():
    with conn.cursor() as cur:
        cur.execute("SELECT id, email, role, username, uid FROM admin ORDER BY id")
        return cur.fetchall()

@router.get("/admins/{admin_id}", response_model=Admin)
def get_admin(admin_id: int):
    with conn.cursor() as cur:
        cur.execute("SELECT id, email, role, username, uid FROM admin WHERE id = %s", (admin_id,))
        result = cur.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Admin not found")
        return result

@router.put("/admins/{admin_id}", response_model=Admin)
def update_admin(admin_id: int, admin: Admin):
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE admin
            SET email = %s, role = %s, username = %s, uid = %s
            WHERE id = %s
            RETURNING id, email, role, username, uid
        """, (admin.email, admin.role, admin.username, admin.uid, admin_id))
        updated_admin = cur.fetchone()
        conn.commit()
        if not updated_admin:
            raise HTTPException(status_code=404, detail="Admin not found")
    return updated_admin

@router.delete("/admins/{admin_id}")
def delete_admin(admin_id: int):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM admin WHERE id = %s", (admin_id,))
        conn.commit()
    return {"message": "Admin deleted"}
