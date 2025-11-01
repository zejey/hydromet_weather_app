"""
Enhanced Notification System
Sends both in-app (Firestore) and SMS notifications
"""

from google.cloud import firestore
from datetime import datetime
import pytz
import os
import requests
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "service-key.json"

# IPROGSMS Configuration
IPROGSMS_API_KEY = os.getenv("IPROGSMS_API_KEY")  # Store in environment variable

# Default recipient numbers (can be overridden per notification)
# DEFAULT_SMS_RECIPIENTS = [
#     os.getenv("SMS_RECIPIENT_1", "+63912345678"),  # Main admin
#     os.getenv("SMS_RECIPIENT_2", "+63987654321"),  # Secondary admin
# ]

class SMSNotificationService:
    """Handle SMS notifications via IPROGSMS"""
    
    SINGLE_SMS_URL = "https://sms.iprogtech.com/api/v1/sms_messages"
    BULK_SMS_URL = "https://sms.iprogtech.com/api/v1/sms_messages/send_bulk"
    
    def __init__(self, api_key=IPROGSMS_API_KEY):
        self.api_key = api_key
        
        if not self.api_key:
            logger.warning("⚠️ IPROGSMS_API_KEY not set. SMS notifications disabled.")
    
    def send_sms(self, phone_number, message):
        """
        Send SMS via IPROGSMS API (Single recipient)
        
        Args:
            phone_number (str): Recipient phone number (e.g., +63912345678 or 09092418164)
            message (str): Message content (max 160 chars for standard SMS)
        
        Returns:
            dict: Response from IPROGSMS API
        """
        if not self.api_key:
            logger.error("❌ IPROGSMS API key not configured")
            return {"status": "error", "message": "SMS service not configured"}
        
        # Truncate message if too long (standard SMS = 160 chars)
        if len(message) > 160:
            message = message[:157] + "..."
        
        # Single SMS payload
        payload = {
            "api_token": self.api_key,
            "phone_number": phone_number,
            "message": message,
        }
        
        try:
            logger.info(f"📱 Sending SMS to {phone_number}...")
            logger.debug(f"   URL: {self.SINGLE_SMS_URL}")
            logger.debug(f"   Payload: {payload}")
            
            response = requests.post(self.SINGLE_SMS_URL, json=payload, timeout=10)
            
            logger.debug(f"   Response Status: {response.status_code}")
            logger.debug(f"   Response Body: {response.text}")
            
            if response.status_code == 200:
                result = response.json()
                logger.debug(f"   Parsed JSON: {result}")
                
                # Check for success - IPROGSMS returns "success": true when queued
                if result.get("success") or "successfully" in result.get("message", "").lower():
                    logger.info(f"✓ SMS queued successfully for {phone_number}")
                    return {"status": "success", "phone": phone_number, "response": result}
                else:
                    logger.error(f"✗ SMS API error: {result.get('message', 'Unknown error')}")
                    return {"status": "failed", "phone": phone_number, "response": result}
            else:
                logger.error(f"✗ HTTP error {response.status_code}: {response.text}")
                return {"status": "error", "phone": phone_number, "http_status": response.status_code}
        
        except requests.exceptions.Timeout:
            logger.error(f"✗ SMS request timeout for {phone_number}")
            return {"status": "timeout", "phone": phone_number}
        except Exception as e:
            logger.error(f"✗ SMS error: {str(e)}")
            return {"status": "exception", "phone": phone_number, "error": str(e)}
    
    def send_bulk_sms(self, recipients, message):
        """
        Send SMS to multiple recipients using bulk endpoint
        
        Args:
            recipients (list): List of phone numbers
            message (str): Message content
        
        Returns:
            dict: Summary of all send attempts
        """
        if len(recipients) == 1:
            # Use single SMS endpoint for one recipient
            result = self.send_sms(recipients[0], message)
            return {
                "total": 1,
                "successful": 1 if result["status"] == "success" else 0,
                "failed": 0 if result["status"] == "success" else 1,
                "details": [result]
            }
        
        # Use bulk SMS endpoint for multiple recipients
        if not self.api_key:
            logger.error("❌ IPROGSMS API key not configured")
            return {"total": len(recipients), "successful": 0, "failed": len(recipients), "details": []}
        
        # Truncate message if too long
        if len(message) > 160:
            message = message[:157] + "..."
        
        # Format phone numbers as comma-separated string
        phone_numbers = ",".join(recipients)
        
        # Bulk SMS payload
        payload = {
            "api_token": self.api_key,
            "phone_number": phone_numbers,
            "message": message,
        }
        
        try:
            logger.info(f"📱 Sending bulk SMS to {len(recipients)} recipients...")
            logger.debug(f"   URL: {self.BULK_SMS_URL}")
            logger.debug(f"   Recipients: {phone_numbers}")
            
            response = requests.post(self.BULK_SMS_URL, json=payload, timeout=10)
            
            logger.debug(f"   Response Status: {response.status_code}")
            logger.debug(f"   Response Body: {response.text}")
            
            if response.status_code == 200:
                result = response.json()
                logger.debug(f"   Parsed JSON: {result}")
                
                if result.get("success") or "successfully" in result.get("message", "").lower():
                    logger.info(f"✓ Bulk SMS queued successfully for {len(recipients)} recipients")
                    return {
                        "total": len(recipients),
                        "successful": len(recipients),
                        "failed": 0,
                        "details": [{"status": "success", "phone": phone_numbers, "response": result}]
                    }
                else:
                    logger.error(f"✗ Bulk SMS API error: {result.get('message', 'Unknown error')}")
                    return {
                        "total": len(recipients),
                        "successful": 0,
                        "failed": len(recipients),
                        "details": [{"status": "failed", "response": result}]
                    }
            else:
                logger.error(f"✗ HTTP error {response.status_code}: {response.text}")
                return {
                    "total": len(recipients),
                    "successful": 0,
                    "failed": len(recipients),
                    "details": [{"status": "error", "http_status": response.status_code}]
                }
        
        except requests.exceptions.Timeout:
            logger.error(f"✗ Bulk SMS request timeout")
            return {"total": len(recipients), "successful": 0, "failed": len(recipients), "details": []}
        except Exception as e:
            logger.error(f"✗ Bulk SMS error: {str(e)}")
            return {"total": len(recipients), "successful": 0, "failed": len(recipients), "details": []}


class NotificationService:
    """Combined in-app + SMS notification service"""
    
    def __init__(self):
        self.db = firestore.Client()
        self.sms_service = SMSNotificationService()
    
    def send_notification(
        self,
        title,
        message,
        notif_type="Warning",
        status="Active",
        sent_to=0,
        dt=None,
        send_sms=True,
        sms_recipients=None
    ):
        """
        Send both in-app and SMS notifications
        
        Args:
            title (str): Notification title
            message (str): Notification message (long version for in-app)
            notif_type (str): Type of notification
            status (str): Status (Active, Resolved, etc.)
            sent_to (int): User ID (0 for broadcast)
            dt (datetime): Timestamp
            send_sms (bool): Whether to send SMS
            sms_recipients (list): Phone numbers for SMS (uses defaults if None)
        """
        now = dt or datetime.now(pytz.timezone("Asia/Manila"))
        
        # ===== SEND IN-APP NOTIFICATION =====
        try:
            in_app_doc = {
                'dateTime': firestore.SERVER_TIMESTAMP,
                'message': message,
                'title': title,
                'type': notif_type,
                'status': status,
                'sentTo': sent_to
            }
            self.db.collection('notifications').add(in_app_doc)
            logger.info(f"✓ In-app notification saved: {title}")
        except Exception as e:
            logger.error(f"✗ Failed to save in-app notification: {str(e)}")
        
        # ===== SEND SMS NOTIFICATION =====
        if send_sms:
            # Use provided recipients or defaults
            recipients = sms_recipients or DEFAULT_SMS_RECIPIENTS
            
            # Create shorter SMS message (SMS has character limit)
            sms_message = self._create_sms_message(title, message)
            
            sms_results = self.sms_service.send_bulk_sms(
                recipients=recipients,
                message=sms_message,
                message_type="text"
            )
            
            logger.info(f"📱 SMS Results: {sms_results['successful']}/{sms_results['total']} sent")
            
            # Save SMS send results to Firestore for audit trail
            try:
                self.db.collection('sms_audit_log').document().set({  # <-- Changed from 'notifications'
                    'dateTime': firestore.SERVER_TIMESTAMP,
                    'type': 'SMS_SENT',
                    'title': title,
                    'sms_results': {
                        'total': sms_results['total'],
                        'successful': sms_results['successful'],
                        'failed': sms_results['failed']
                    },
                    'recipients': len(recipients)
                })
            except Exception as e:
                logger.error(f"✗ Failed to log SMS results: {str(e)}")
    
    def _create_sms_message(self, title, long_message):
        """
        Create a concise SMS message from title and long message
        SMS limit: 160 characters
        """
        # Extract key info from message
        sms_msg = f"{title}: {long_message[:120]}"
        
        # Truncate if needed
        if len(sms_msg) > 160:
            sms_msg = sms_msg[:157] + "..."
        
        return sms_msg


# ===== CONVENIENCE FUNCTIONS =====

def send_event_notification(
    title,
    message,
    notif_type="Warning",
    status="Active",
    sent_to=0,
    dt=None,
    send_sms=True,
    sms_recipients=None
):
    """
    Legacy function for backward compatibility
    Sends both in-app and SMS notifications
    """
    service = NotificationService()
    service.send_notification(
        title=title,
        message=message,
        notif_type=notif_type,
        status=status,
        sent_to=sent_to,
        dt=dt,
        send_sms=send_sms,
        sms_recipients=sms_recipients
    )


def send_sms_only(phone_numbers, message):
    """Send SMS without in-app notification"""
    sms_service = SMSNotificationService()
    return sms_service.send_sms(phone_numbers, message)


def send_weather_alert(hazard_type, message, recipients=None):
    """
    Convenience function for weather alerts
    Automatically formats notification for both channels
    """
    service = NotificationService()
    service.send_notification(
        title=f"⚠️ {hazard_type} Alert",
        message=message,
        notif_type="Alert",
        status="Active",
        send_sms=True,
        sms_recipients=recipients
    )