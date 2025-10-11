from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
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

class Notification(BaseModel):
    id: str
    title: str
    message: str
    type: str
    sent_to: str
    status: str
    date_time: datetime = None

@router.post("/notifications", response_model=Notification)
def create_notification(notification: Notification):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO notifications (id, title, message, type, sent_to, status, date_time)
            VALUES (%s,%s,%s,%s,%s,%s,%s)
        """, (
            notification.id, notification.title, notification.message,
            notification.type, notification.sent_to, notification.status,
            notification.date_time
        ))
        conn.commit()
    return notification

@router.get("/notifications", response_model=List[Notification])
def get_notifications():
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM notifications ORDER BY date_time DESC")
        return cur.fetchall()

@router.get("/notifications/{notif_id}", response_model=Notification)
def get_notification(notif_id: str):
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM notifications WHERE id = %s", (notif_id,))
        result = cur.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Notification not found")
        return result

@router.put("/notifications/{notif_id}", response_model=Notification)
def update_notification(notif_id: str, notification: Notification):
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE notifications SET title=%s, message=%s, type=%s, sent_to=%s, status=%s, date_time=%s WHERE id=%s
        """, (
            notification.title, notification.message, notification.type,
            notification.sent_to, notification.status, notification.date_time,
            notif_id
        ))
        conn.commit()
    return notification

@router.delete("/notifications/{notif_id}")
def delete_notification(notif_id: str):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM notifications WHERE id = %s", (notif_id,))
        conn.commit()
    return {"message": "Notification deleted"}
