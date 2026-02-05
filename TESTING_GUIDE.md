# Email Implementation Testing Guide

## Prerequisites
- Backend API running at: `https://caring-kindness-production.up.railway.app/api`
- Backend supports all required endpoints (see EMAIL_IMPLEMENTATION.md)
- Test email account accessible
- Test phone number capable of receiving SMS

## Test Scenarios

### 1. New User Registration with Email

#### Test Case 1.1: Complete Registration Flow
**Steps:**
1. Open app → Navigate to registration screen
2. Fill in all fields:
   - First Name: "Test"
   - Last Name: "User"
   - House Address: "123 Test St"
   - Barangay: Select any
   - Email: "test@example.com"
   - Phone: "09123456789"
3. Check "I agree to Terms and Conditions"
4. Click "Register"

**Expected:**
- ✅ Loading indicator appears
- ✅ Success message: "Registration successful! Please verify your phone."
- ✅ Navigate to OTP verification screen
- ✅ SMS OTP sent to phone
- ✅ Email attached to user in backend

**Verify Backend:**
```bash
# Check user created
curl https://caring-kindness-production.up.railway.app/api/users/phone/639123456789

# Check email attached
curl https://caring-kindness-production.up.railway.app/api/user-emails/check-phone/639123456789
```

#### Test Case 1.2: Email Validation
**Steps:**
1. Enter invalid emails one at a time:
   - "invalid" (no @)
   - "@example.com" (no local part)
   - "test@" (no domain)
   - "test @example.com" (space in email)
2. Try to submit each time

**Expected:**
- ✅ Error: "Please enter a valid email address"
- ✅ Cannot proceed to OTP screen

#### Test Case 1.3: Duplicate Phone Registration
**Steps:**
1. Try to register with phone already in system
2. Fill all fields including email
3. Click "Register"

**Expected:**
- ✅ Error: "Phone number already registered. Please sign in."

### 2. Phone OTP Verification with Email Fallback

#### Test Case 2.1: SMS OTP Verification
**Steps:**
1. Complete registration → Reach OTP screen
2. Receive SMS OTP
3. Enter 6-digit OTP
4. Auto-submits when 6 digits entered

**Expected:**
- ✅ OTP verified successfully
- ✅ Navigate to Email Verification Prompt screen
- ✅ Shows registered email address
- ✅ Two buttons: "Verify Now" and "Skip for now"

#### Test Case 2.2: Resend OTP via SMS
**Steps:**
1. On OTP screen, wait for countdown (60s)
2. Click "Resend OTP"

**Expected:**
- ✅ "Resend in X s" countdown appears
- ✅ After countdown reaches 0, "Resend OTP" button enabled
- ✅ Click button → Success: "OTP resent successfully"
- ✅ New SMS received

#### Test Case 2.3: Resend OTP via Email
**Steps:**
1. On OTP screen, wait for countdown (60s)
2. Click "Resend via Email" button (blue, with email icon)

**Expected:**
- ✅ "Resend via Email" button appears after countdown
- ✅ Click button → Success: "OTP sent to your email successfully"
- ✅ Check email inbox → OTP received
- ✅ Enter OTP from email → Verification succeeds

#### Test Case 2.4: Invalid OTP
**Steps:**
1. On OTP screen, enter "123456" (wrong OTP)

**Expected:**
- ✅ Error message: "Invalid OTP" or "OTP expired"
- ✅ Input fields cleared
- ✅ Focus returns to first input

### 3. Email Verification Prompt

#### Test Case 3.1: Verify Now Flow
**Steps:**
1. After phone OTP success → Email Verification Prompt appears
2. Click "Verify Now"

**Expected:**
- ✅ Loading indicator appears
- ✅ Success: "Verification code sent to [email]"
- ✅ Navigate to Email OTP Verify screen
- ✅ Check email → OTP received
- ✅ Screen shows email address
- ✅ 6 input boxes for OTP

#### Test Case 3.2: Skip Verification
**Steps:**
1. After phone OTP success → Email Verification Prompt appears
2. Click "Skip for now"

**Expected:**
- ✅ Navigate to Weather/Home screen
- ✅ No error messages
- ✅ User logged in successfully

### 4. Email OTP Verification

#### Test Case 4.1: Successful Verification
**Steps:**
1. On Email OTP screen
2. Check email for OTP code
3. Enter 6-digit code
4. Auto-submits

**Expected:**
- ✅ Success: "Email verified successfully!"
- ✅ Navigate to Weather/Home screen
- ✅ Email status in backend updated to verified
- ✅ No "Unverified" banner in profile

**Verify:**
```bash
curl https://caring-kindness-production.up.railway.app/api/user-emails/check-phone/639123456789
# Should show is_verified: true
```

#### Test Case 4.2: Resend Email OTP
**Steps:**
1. On Email OTP screen
2. Wait 60 seconds
3. Click "Resend"

**Expected:**
- ✅ Countdown shows "Resend in X s"
- ✅ After countdown, "Resend" button enabled
- ✅ Click → Success: "OTP resent successfully"
- ✅ New email received with new OTP

#### Test Case 4.3: Skip Email Verification
**Steps:**
1. On Email OTP screen
2. Click "Skip for now"

**Expected:**
- ✅ Navigate to Weather/Home screen
- ✅ Email remains unverified

### 5. Login Flows

#### Test Case 5.1: Login (Non-Trusted Device)
**Steps:**
1. Logout from app
2. Login with registered phone
3. Enter OTP
4. Verify

**Expected:**
- ✅ OTP sent via SMS
- ✅ Verify succeeds
- ✅ If email unverified: Email Verification Prompt appears
- ✅ Can verify or skip
- ✅ Navigate to Weather/Home screen

#### Test Case 5.2: Login (Trusted Device)
**Steps:**
1. Login with phone previously verified on this device (within 30 days)

**Expected:**
- ✅ No OTP screen (trusted device)
- ✅ Success: "Welcome back! (Trusted device)"
- ✅ If email unverified: Email Verification Prompt appears
- ✅ Can verify or skip
- ✅ Navigate to Weather/Home screen

#### Test Case 5.3: Login Different User
**Steps:**
1. Device trusted for User A (09111111111)
2. Logout
3. Login with User B (09222222222)

**Expected:**
- ✅ Device trust cleared for User A
- ✅ OTP sent to User B
- ✅ Must verify OTP (not trusted)
- ✅ After success, device trusted for User B

### 6. Profile Screen

#### Test Case 6.1: Unverified Email Banner
**Steps:**
1. Login with user who has unverified email
2. Navigate to Profile screen

**Expected:**
- ✅ Orange banner at top of profile info
- ✅ Warning icon displayed
- ✅ Text: "Email Unverified"
- ✅ Shows email address
- ✅ Banner persistent across app restarts

#### Test Case 6.2: No Email Banner
**Steps:**
1. Login with user who has NO email attached
2. Navigate to Profile screen

**Expected:**
- ✅ Blue banner at top of profile info
- ✅ Info icon displayed
- ✅ Text: "No email on file. Add an email for account recovery."

#### Test Case 6.3: Verified Email (No Banner)
**Steps:**
1. Login with user who has verified email
2. Navigate to Profile screen

**Expected:**
- ✅ No banner displayed
- ✅ Only profile information shown

### 7. Edge Cases

#### Test Case 7.1: Network Failure During Registration
**Steps:**
1. Disable network/WiFi
2. Try to register
3. Re-enable network
4. Try again

**Expected:**
- ✅ Error: "Network error: [message]"
- ✅ User not created
- ✅ Can retry after network restored

#### Test Case 7.2: Backend Down
**Steps:**
1. Backend API unavailable
2. Try to register/login

**Expected:**
- ✅ Timeout after 30 seconds
- ✅ Error: "Request timed out"
- ✅ No crash

#### Test Case 7.3: Email Already Exists
**Steps:**
1. Try to register with email already in system (different phone)

**Expected:**
- ✅ Backend validation should prevent duplicate emails
- ✅ Error message from backend displayed
- ✅ Cannot proceed

#### Test Case 7.4: Session Expiry
**Steps:**
1. Login successfully
2. Wait 30 days (or manually change last_login timestamp)
3. Open app

**Expected:**
- ✅ Session expired check runs
- ✅ User logged out automatically
- ✅ Redirect to login screen
- ✅ Message: "Session expired (> 30 days) - logging out"

### 8. Data Persistence

#### Test Case 8.1: App Restart
**Steps:**
1. Complete registration with email verification
2. Close app completely
3. Reopen app

**Expected:**
- ✅ User remains logged in
- ✅ Email verification status preserved
- ✅ Correct banner shown in profile

#### Test Case 8.2: Device Trust Persistence
**Steps:**
1. Verify OTP on device
2. Logout (not different user)
3. Close app
4. Reopen and login with same phone

**Expected:**
- ✅ Device still trusted
- ✅ No OTP required
- ✅ Direct login succeeds

## Test Data Cleanup

After testing, clean up test data:
```bash
# Delete test user (backend admin only)
# Or use backend admin panel to remove test accounts
```

## Regression Testing

After any code changes, re-run:
- Test Case 1.1 (Complete Registration)
- Test Case 2.3 (Resend via Email)
- Test Case 4.1 (Email Verification)
- Test Case 5.2 (Trusted Device Login)
- Test Case 6.1 (Unverified Banner)

## Performance Testing

### Load Test
- Register 10 users simultaneously
- Verify no crashes or data corruption

### Stress Test
- Rapidly click "Resend OTP" multiple times
- Verify countdown prevents spam

## Checklist

**Registration Flow:**
- [ ] Email field required and validated
- [ ] Email attached before OTP screen
- [ ] Resend via Email works

**Email Verification:**
- [ ] Prompt appears after phone OTP
- [ ] Verify Now sends email OTP
- [ ] Email OTP verification works
- [ ] Skip option works

**Login Flows:**
- [ ] Non-trusted device → OTP → Email prompt
- [ ] Trusted device → Skip OTP → Email prompt
- [ ] Different user → Clear trust → OTP

**Profile:**
- [ ] Unverified banner shows
- [ ] No email banner shows
- [ ] Verified = no banner

**Edge Cases:**
- [ ] Network errors handled
- [ ] Invalid inputs rejected
- [ ] Session expiry works
- [ ] Data persists across restarts

## Known Issues / Limitations

1. Email verification cannot be triggered from Settings (future enhancement)
2. No way to change email after registration (future enhancement)
3. Debug print statements still present (remove before production)
4. SharedPreferences used instead of SecureStorage (consider upgrading)

## Support

For issues:
1. Check logs for error messages
2. Verify backend API is accessible
3. Confirm all endpoints return expected responses
4. Check device logs: `adb logcat | grep Flutter` (Android) or Xcode console (iOS)
