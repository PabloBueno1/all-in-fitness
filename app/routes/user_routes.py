from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User
from app.schemas import UserCreate, UserLogin
from app.auth import get_password_hash, verify_password, create_access_token, get_current_user
from fastapi.security import OAuth2PasswordRequestForm

router = APIRouter()

@router.post("/users")
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_password = get_password_hash(user.password)
    new_user = User(name=user.name, email=user.email, hashed_password=hashed_password)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "User created successfully"}

@router.post("/token")
def login_for_access_token(user: UserLogin, db: Session = Depends(get_db)):
    user_in_db = db.query(User).filter(User.email == user.email).first()
    if not user_in_db or not verify_password(user.password, user_in_db.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    access_token = create_access_token(data={"sub": str(user_in_db.id)})
    return {"access_token": access_token, "token_type": "bearer"}

#Oauth Testing
# @router.post("/token")
# async def oauth_login_for_access_token(
#     db: Session = Depends(get_db),
#     form_data: OAuth2PasswordRequestForm = Depends()  # Used for Swagger UI (OAuth2)
# ):
#     """
#     ✅ Supports only:
#     - OAuth2 form data (Swagger UI)
#     """

#     email = form_data.username  # OAuth2 uses "username", treat it as "email"
#     password = form_data.password

#     # Validate user
#     user_in_db = db.query(User).filter(User.email == email).first()
#     if not user_in_db or not verify_password(password, user_in_db.hashed_password):
#         raise HTTPException(status_code=400, detail="Incorrect email or password")

#     # Generate token
#     access_token = create_access_token(data={"sub": str(user_in_db.id)})
#     return {"access_token": access_token, "token_type": "bearer"}

@router.get("/users/me")
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user