from fastapi import FastAPI
from database.admin_api import router as admin_router
from database.user_api import router as user_router
from database.notifications_api import router as notifications_router
from database.emergency_hotlines_api import router as hotlines_router
from database.safety_category_api import router as safety_category_router
from database.safety_tips_api import router as safety_tips_router
# from database.preventive_measures_api import router as measures_router
# ... add other routers as needed

app = FastAPI()

app.include_router(admin_router)
app.include_router(user_router)
app.include_router(notifications_router)
app.include_router(hotlines_router)
app.include_router(safety_category_router)
app.include_router(safety_tips_router)
# app.include_router(measures_router)
# ... add other routers
