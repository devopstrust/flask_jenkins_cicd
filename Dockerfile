#збірка залежностей
FROM python:3.12-alpine AS builder
WORKDIR /app
# Копіюємо requirements.txt
COPY app/requirements.txt .
RUN apk add --no-cache gcc musl-dev linux-headers && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

#кінцевий образ
FROM python:3.12-alpine
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY app/ .
EXPOSE 5000
CMD ["python", "server.py"]