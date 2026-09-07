
docker login

# 1. 최신 이미지 Pull (oliver173 계정)
docker pull oliver173/mts-account:latest
docker pull oliver173/mts-trading:latest
docker pull oliver173/mts-admin:latest
docker pull oliver173/mts-price-generator:latest
docker pull oliver173/mts-trading-bot:latest
docker pull oliver173/mts-trade-verifier:latest

# 2. 기존 컨테이너 중지 및 이미지 정리
docker-compose down
# 3. 서비스 시작
docker-compose up -d