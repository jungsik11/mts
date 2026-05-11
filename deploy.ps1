
docker login

# 1. 최신 이미지 Pull (oliver173 계정)
docker pull oliver173/mts-account:latest
docker pull oliver173/mts-trading:latest
docker pull oliver173/mts-admin:latest
docker pull oliver173/mts-price-generator:latest
docker pull oliver173/mts-trading-bot:latest

# 2. 기존 컨테이너 중지 및 이미지 강제 삭제
docker-compose down
# 기존 oliver173 이미지들도 삭제하여 확실하게 새로 받음
docker rmi oliver173/mts-account oliver173/mts-trading oliver173/mts-admin oliver173/mts-price-generator oliver173/mts-trading-bot 2>/dev/null || true
# 예전 jungsik11 이름으로 된 이미지들 삭제
docker rmi jungsik11/mts-account-server jungsik11/mts-trading-server jungsik11/mts-price-generator jungsik11/mts-trading-bot jungsik11/mts-admin-web 2>/dev/null || true

# 3. 최신 이미지 다시 Pull 및 서비스 시작
docker-compose pull
docker-compose up -d