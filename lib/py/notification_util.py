from google.cloud import firestore
from datetime import datetime
import pytz
import os

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "weather-app-e40b4-9a892c181935.json"

def send_event_notification(title, message, notif_type="Warning", status="Active", sent_to=0, dt=None):
    """
    Send a notification document to Firestore for a detected weather event.
    """
    db = firestore.Client()
    now = dt or datetime.now(pytz.timezone("Asia/Manila"))
    # Use Firestore Timestamp, NOT string!
    doc = {
        'dateTime': firestore.SERVER_TIMESTAMP,  # or now if you want to control the time
        'message': message,
        'title': title,
        'type': notif_type,
        'status': status,
        'sentTo': sent_to
    }
    db.collection('notifications').add(doc)

title = "may bagyo"
message = "takbo"

send_event_notification(title, message)