# 📦 Order API Service

REST API сервис для добавления товаров в заказ на базе **FastAPI** + **PostgreSQL**.

## 🎯 Основные возможности

- ✅ **Добавление товара в заказ** через REST API
- ✅ **Автоматическое увеличение количества** при повторном добавлении товара
- ✅ **Проверка наличия товара** на складе
- ✅ **Обновление остатков** после добавления
- ✅ **Пересчет итоговой суммы** заказа
- ✅ **Полная контейнеризация** с Docker Compose
- ✅ **Автоматическая документация** Swagger UI и ReDoc
- ✅ **Валидация данных** через Pydantic
- ✅ **PostgreSQL** с тестовыми данными

## 🚀 Быстрый старт

### Требования

- Docker и Docker Compose
- Python 3.11+ (для локальной разработки)

### 1. Клонировать репозиторий

```bash
git clone https://github.com/your-repo/order-api-service.git
cd order-api-service
```

### 2. Создать .env файл

```bash
cp .env.example .env
```

### 3. Запустить через Docker Compose

```bash
docker-compose up --build
```

Это запустит:
- **PostgreSQL** на порту 5432
- **FastAPI** приложение на порту 8000

### 4. Проверить работу

Откройте в браузере:
- **API документация (Swagger)**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health check**: http://localhost:8000/health

## 📖 API Документация

### Основной эндпоинт

#### `POST /api/v1/orders/{order_id}/items`

Добавляет товар в заказ.

**Параметры URL:**
- `order_id` (int) - ID заказа

**Тело запроса:**
```json
{
  "product_id": 1,
  "quantity": 2.5
}
```

**Ответ (200 OK):**
```json
{
  "success": true,
  "action": "created",
  "message": "Товар 'Ноутбук Lenovo IdeaPad 3' добавлен в заказ ORD-2025-001",
  "order": {
    "id": 1,
    "order_number": "ORD-2025-001",
    "total_amount": 112500.0,
    "final_amount": 112500.0,
    "items_count": 1
  },
  "item": {
    "id": 1,
    "product_id": 1,
    "product_name": "Ноутбук Lenovo IdeaPad 3",
    "quantity": 2.5,
    "unit": "шт",
    "unit_price": 45000.0,
    "line_total": 112500.0
  },
  "product_remaining": {
    "quantity": 7.5,
    "unit": "шт"
  }
}
```

**Ошибки:**

- `404 Not Found` - Заказ или товар не найден
- `400 Bad Request` - Недостаточно товара на складе или товар неактивен

### Дополнительные эндпоинты

#### `GET /api/v1/orders/{order_id}`
Получить информацию о заказе

#### `GET /api/v1/products`
Список всех активных товаров

#### `GET /api/v1/products/{product_id}`
Информация о конкретном товаре

## 💡 Примеры использования

### cURL

```bash
# Добавить товар в заказ
curl -X POST "http://localhost:8000/api/v1/orders/1/items" \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": 1,
    "quantity": 2
  }'

# Получить заказ
curl -X GET "http://localhost:8000/api/v1/orders/1"

# Список товаров
curl -X GET "http://localhost:8000/api/v1/products"
```

### Python (requests)

```python
import requests

# Добавить товар в заказ
response = requests.post(
    "http://localhost:8000/api/v1/orders/1/items",
    json={
        "product_id": 1,
        "quantity": 2.0
    }
)
print(response.json())
```

### JavaScript (fetch)

```javascript
fetch('http://localhost:8000/api/v1/orders/1/items', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    product_id: 1,
    quantity: 2.0
  })
})
.then(response => response.json())
.then(data => console.log(data));
```

## 🏗️ Архитектура

```
order-api-service/
├── app/
│   ├── api/
│   │   └── v1/
│   │       └── endpoints.py      # REST API эндпоинты
│   ├── core/
│   │   └── config.py             # Конфигурация
│   ├── db/
│   │   ├── database.py           # Подключение к БД
│   │   └── session.py            # Dependency для сессий
│   ├── models/
│   │   └── models.py             # SQLAlchemy модели
│   ├── schemas/
│   │   └── order.py              # Pydantic схемы
│   ├── services/
│   │   └── order_service.py      # Бизнес-логика
│   └── main.py                   # Точка входа
├── tests/
│   └── test_api.py               # Тесты
├── docker-compose.yml            # Docker Compose конфигурация
├── Dockerfile                    # Docker образ приложения
├── requirements.txt              # Python зависимости
├── init.sql                      # Тестовые данные для БД
└── README.md                     # Документация
```

## 🔧 Локальная разработка

### Без Docker

1. Создать виртуальное окружение:
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# или
venv\Scripts\activate  # Windows
```

2. Установить зависимости:
```bash
pip install -r requirements.txt
```

3. Настроить БД (PostgreSQL или SQLite):
```bash
# Для SQLite измените DATABASE_URL в .env:
# DATABASE_URL=sqlite:///./test.db
```

4. Запустить сервер:
```bash
uvicorn app.main:app --reload
```

## 🧪 Тестирование

```bash
# Запустить тесты
pytest

# С coverage
pytest --cov=app tests/
```

## 📊 Схема базы данных

```sql
customers
├── id (PK)
├── name
└── email

products
├── id (PK)
├── name
├── quantity
├── price
├── unit
└── is_active

orders
├── id (PK)
├── order_number
├── customer_id (FK)
├── status
├── total_amount
└── final_amount

order_items
├── id (PK)
├── order_id (FK)
├── product_id (FK)
├── quantity
├── unit_price
└── line_total
```

## 🔒 Безопасность

- ✅ SQL Injection защита через SQLAlchemy ORM
- ✅ Валидация входных данных через Pydantic
- ✅ CHECK constraints на уровне БД
- ✅ Транзакции для атомарности операций

## 🎓 Технологии

- **FastAPI** 0.115+ - современный веб-фреймворк
- **SQLAlchemy** 2.0+ - ORM для работы с БД
- **Pydantic** 2.0+ - валидация данных
- **PostgreSQL** 15 - реляционная БД
- **Docker** & **Docker Compose** - контейнеризация
- **Uvicorn** - ASGI сервер

## 📝 Лицензия

MIT

## 👨‍💻 Автор

Разработано для вакансии Middle Backend разработчик в Aiti Guru

---

**Документация API**: http://localhost:8000/docs

**Health Check**: http://localhost:8000/health
