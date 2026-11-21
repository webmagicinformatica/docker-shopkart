# Part 1: the ShopKart API in a container. Simple, and it works.
FROM python:3.12.16-slim-trixie
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
