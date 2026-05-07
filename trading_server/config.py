from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    KIS_APPKEY: str
    KIS_SECRET: str
    KIS_ACCOUNT: str
    KIS_URL: str = "https://openapi.koreainvestment.com:9443" # Real or Sandbox
    
    class Config:
        env_file = ".env"

settings = Settings()
