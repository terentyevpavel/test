-- Инициализация базы данных с тестовыми данными

-- Создание клиентов
INSERT INTO customers (id, name, email) VALUES
(1, 'ООО "Рога и Копыта"', 'info@rogakopyta.ru'),
(2, 'ИП Иванов И.И.', 'ivanov@example.com')
ON CONFLICT DO NOTHING;

-- Создание товаров
INSERT INTO products (id, name, quantity, price, unit, is_active) VALUES
(1, 'Ноутбук Lenovo IdeaPad 3', 10.000, 45000.00, 'шт', TRUE),
(2, 'Ноутбук ASUS VivoBook', 7.000, 52000.00, 'шт', TRUE),
(3, 'Холодильник Samsung RB37', 5.000, 65000.00, 'шт', TRUE),
(4, 'Холодильник LG GC-B247', 3.000, 58000.00, 'шт', TRUE),
(5, 'Телевизор Samsung UE55', 8.000, 75000.00, 'шт', TRUE)
ON CONFLICT DO NOTHING;

-- Создание тестового заказа
INSERT INTO orders (id, order_number, customer_id, status, total_amount, final_amount) VALUES
(1, 'ORD-2025-001', 1, 'новый', 0, 0)
ON CONFLICT DO NOTHING;

-- Сброс последовательностей
SELECT setval('customers_id_seq', (SELECT MAX(id) FROM customers));
SELECT setval('products_id_seq', (SELECT MAX(id) FROM products));
SELECT setval('orders_id_seq', (SELECT MAX(id) FROM orders));
