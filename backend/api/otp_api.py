"""
OTP API endpoints
"""

from fastapi import APIRouter, HTTPException, status

from backend.models.otp import OTPRequest, OTPVerifyRequest, OTPResponse
from backend.services.otp_manager import OTPManager

router = APIRouter(prefix="/api/otp", tags=["OTP"])

# Initialize OTP Manager
otp_manager = OTPManager()


@router.post("/send", response_model=OTPResponse)
async def send_otp(request: OTPRequest):  # ← Changed from dict to OTPRequest
    """
    Send OTP to phone number
    
    Request Body:
    {
        "phone_number": "639109432834"
    }
    
    Response:
    {
        "success": true,
        "message": "OTP sent successfully",
        "data": {
            "otp_id": 1,
            "phone_number": "639109432834",
            "expires_at": "2025-11-01T14:27:30Z",
            "validity_minutes": 5
        }
    }
    """
    try:
        success, message, result_data = otp_manager.send_otp(request.phone_number)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=message
            )
        
        return OTPResponse(
            success=success,
            message=message,
            data=result_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )


@router.post("/verify", response_model=OTPResponse)
async def verify_otp(request: OTPVerifyRequest):
    """
    Verify OTP code
    
    Request Body:
    {
        "phone_number": "639109432834",
        "otp_code": "123456"
    }
    
    Response:
    {
        "success": true,
        "message": "OTP verified successfully",
        "data": {
            "otp_id": 1,
            "phone_number": "639109432834",
            "verified_at": "2025-11-01T14:25:30Z"
        }
    }
    """
    try:
        success, message, result_data = otp_manager.verify_otp(
            request.phone_number,
            request.otp_code
        )
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=message
            )
        
        return OTPResponse(
            success=success,
            message=message,
            data=result_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )


@router.post("/resend", response_model=OTPResponse)
async def resend_otp(request: OTPRequest):
    """
    Resend OTP to phone number
    
    Request Body:
    {
        "phone_number": "639109432834"
    }
    """
    try:
        success, message, result_data = otp_manager.resend_otp(request.phone_number)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=message
            )
        
        return OTPResponse(
            success=success,
            message=message,
            data=result_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )


@router.get("/health")
async def health_check():
    """Check if OTP service is running"""
    return {
        "success": True,
        "message": "OTP service is running",
        "data": {
            "service": "OTP Manager",
            "status": "healthy"
        }
    }