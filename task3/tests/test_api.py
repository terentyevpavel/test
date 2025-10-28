"""
Тесты для API
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from decimal import Decimal

from app.main import app
from app.db.database import Base
from app.db.session import get_db
from app.models.models import Customer, Product, Order

# Тестовая БД в памяти
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)


@pytest.fixture
def setup_test_data():
    """Подготовить тестовые данные"""
    db = TestingSessionLocal()

    # Очистить таблицы
    db.query(Order).delete()
    db.query(Product).delete()
    db.query(Customer).delete()
    db.commit()

    # Создать клиента
    customer = Customer(id=1, name="Test Customer", email="test@example.com")
    db.add(customer)

    # Создать товары
    products = [
        Product(id=1, name="Ноутбук", quantity=Decimal("10.0"), price=Decimal("50000.0"), unit="шт"),
        Product(id=2, name="Мышь", quantity=Decimal("5.0"), price=Decimal("1000.0"), unit="шт"),
    ]
    db.add_all(products)

    # Создать заказ
    order = Order(id=1, order_number="TEST-001", customer_id=1, status="новый")
    db.add(order)

    db.commit()
    db.close()

    yield

    # Очистка после теста
    db = TestingSessionLocal()
    db.query(Order).delete()
    db.query(Product).delete()
    db.query(Customer).delete()
    db.commit()
    db.close()


def test_root():
    """Тест корневого эндпоинта"""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "running"


def test_health_check():
    """Тест health check"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_add_item_to_order_success(setup_test_data):
    """Тест успешного добавления товара в заказ"""
    response = client.post(
        "/api/v1/orders/1/items",
        json={"product_id": 1, "quantity": 2.0}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["action"] == "created"
    assert data["item"]["product_id"] == 1
    assert data["item"]["quantity"] == 2.0
    assert data["product_remaining"]["quantity"] == 8.0


def test_add_item_increases_quantity(setup_test_data):
    """Тест увеличения количества при повторном добавлении"""
    # Первое добавление
    client.post("/api/v1/orders/1/items", json={"product_id": 1, "quantity": 2.0})

    # Второе добавление того же товара
    response = client.post(
        "/api/v1/orders/1/items",
        json={"product_id": 1, "quantity": 3.0}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["action"] == "updated"
    assert data["item"]["quantity"] == 5.0  # 2 + 3
    assert data["product_remaining"]["quantity"] == 5.0  # 10 - 5


def test_add_item_insufficient_stock(setup_test_data):
    """Тест ошибки при недостаточном количестве товара"""
    response = client.post(
        "/api/v1/orders/1/items",
        json={"product_id": 1, "quantity": 15.0}  # Больше чем есть (10)
    )

    assert response.status_code == 400
    assert "Недостаточно товара" in response.json()["detail"]


def test_add_item_order_not_found(setup_test_data):
    """Тест ошибки при несуществующем заказе"""
    response = client.post(
        "/api/v1/orders/999/items",
        json={"product_id": 1, "quantity": 1.0}
    )

    assert response.status_code == 404
    assert "не найден" in response.json()["detail"]


def test_add_item_product_not_found(setup_test_data):
    """Тест ошибки при несуществующем товаре"""
    response = client.post(
        "/api/v1/orders/1/items",
        json={"product_id": 999, "quantity": 1.0}
    )

    assert response.status_code == 404
    assert "не найден" in response.json()["detail"]
