
-- ═══════════════════════════════════════════════════════════════════════════════
-- SQL ЗАПРОСЫ ДЛЯ ERP СИСТЕМЫ
-- Технические задания 2.1, 2.2, 2.3
-- ═══════════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2.1. Получение информации о сумме товаров, заказанных под каждого клиента
--      (Наименование клиента, сумма)
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT 
    c.name AS "Наименование клиента",
    COALESCE(SUM(o.final_amount), 0) AS "Сумма"
FROM 
    customers c
    LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY 
    c.id, c.name
ORDER BY 
    "Сумма" DESC;

-- Альтернативный вариант: только клиенты с заказами (INNER JOIN)
SELECT 
    c.name AS "Наименование клиента",
    SUM(o.final_amount) AS "Сумма"
FROM 
    customers c
    INNER JOIN orders o ON c.id = o.customer_id
GROUP BY 
    c.id, c.name
ORDER BY 
    "Сумма" DESC;

-- Расширенный вариант с дополнительной статистикой
SELECT 
    c.id AS "ID клиента",
    c.name AS "Наименование клиента",
    c.customer_type AS "Тип клиента",
    COUNT(o.id) AS "Количество заказов",
    COALESCE(SUM(o.final_amount), 0) AS "Общая сумма",
    COALESCE(AVG(o.final_amount), 0) AS "Средний чек",
    MAX(o.order_date) AS "Последний заказ"
FROM 
    customers c
    LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY 
    c.id, c.name, c.customer_type
ORDER BY 
    "Общая сумма" DESC;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2.2. Найти количество дочерних элементов первого уровня вложенности
--      для категорий номенклатуры
-- ═══════════════════════════════════════════════════════════════════════════════

-- Вариант 1: Подсчет прямых потомков (level + 1)
SELECT 
    parent.id AS "ID категории",
    parent.name AS "Наименование категории",
    parent.level AS "Уровень",
    COUNT(child.id) AS "Количество дочерних элементов 1-го уровня"
FROM 
    categories parent
    LEFT JOIN categories child ON child.parent_id = parent.id
GROUP BY 
    parent.id, parent.name, parent.level
ORDER BY 
    parent.level, parent.id;

-- Вариант 2: Только категории, у которых ЕСТЬ дочерние элементы
SELECT 
    parent.id AS "ID категории",
    parent.name AS "Наименование категории",
    parent.level AS "Уровень",
    COUNT(child.id) AS "Количество дочерних элементов 1-го уровня"
FROM 
    categories parent
    INNER JOIN categories child ON child.parent_id = parent.id
GROUP BY 
    parent.id, parent.name, parent.level
HAVING 
    COUNT(child.id) > 0
ORDER BY 
    "Количество дочерних элементов 1-го уровня" DESC;

-- Вариант 3: С дополнительной информацией о потомках
SELECT 
    parent.id AS "ID категории",
    parent.name AS "Наименование категории",
    parent.level AS "Уровень",
    COUNT(child.id) AS "Количество дочерних элементов",
    STRING_AGG(child.name, ', ' ORDER BY child.name) AS "Дочерние категории"
FROM 
    categories parent
    LEFT JOIN categories child ON child.parent_id = parent.id
GROUP BY 
    parent.id, parent.name, parent.level
ORDER BY 
    parent.level, parent.id;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2.3.1. VIEW: Топ-5 самых покупаемых товаров за последний месяц
--        (по количеству штук в заказах)
--        Поля: Наименование товара, Категория 1-го уровня, Общее количество
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW top_products_last_month AS
WITH 
-- CTE 1: Получаем продажи за последний месяц
recent_sales AS (
    SELECT 
        oi.product_id,
        SUM(oi.quantity) AS total_quantity
    FROM 
        order_items oi
        INNER JOIN orders o ON oi.order_id = o.id
    WHERE 
        o.order_date >= CURRENT_DATE - INTERVAL '1 month'
        AND o.status != 'отменен'  -- Исключаем отмененные заказы
    GROUP BY 
        oi.product_id
),
-- CTE 2: Получаем категорию 1-го уровня для каждого товара
product_top_categories AS (
    SELECT DISTINCT ON (p.id)
        p.id AS product_id,
        p.name AS product_name,
        CASE 
            WHEN c.level = 0 THEN c.name
            WHEN c.level = 1 THEN c.name
            WHEN c.level >= 2 THEN (
                -- Рекурсивно находим родителя 1-го уровня
                SELECT parent.name
                FROM categories parent
                WHERE parent.id = (
                    SELECT parent_id 
                    FROM categories 
                    WHERE id = c.parent_id
                )
                AND parent.level = 1
            )
        END AS category_level_1
    FROM 
        products p
        INNER JOIN product_categories pc ON p.id = pc.product_id
        INNER JOIN categories c ON pc.category_id = c.id
    WHERE 
        pc.is_primary = TRUE  -- Берем только основную категорию
    ORDER BY 
        p.id, pc.is_primary DESC
)
SELECT 
    pct.product_name AS "Наименование товара",
    COALESCE(pct.category_level_1, 'Без категории') AS "Категория 1-го уровня",
    rs.total_quantity AS "Общее количество проданных штук"
FROM 
    recent_sales rs
    INNER JOIN product_top_categories pct ON rs.product_id = pct.product_id
ORDER BY 
    rs.total_quantity DESC
LIMIT 5;


-- Альтернативная версия VIEW с использованием Recursive CTE
-- Более надежная для категорий любой глубины
CREATE OR REPLACE VIEW top_products_last_month_v2 AS
WITH 
-- CTE 1: Продажи за последний месяц
recent_sales AS (
    SELECT 
        oi.product_id,
        SUM(oi.quantity) AS total_quantity
    FROM 
        order_items oi
        INNER JOIN orders o ON oi.order_id = o.id
    WHERE 
        o.order_date >= CURRENT_DATE - INTERVAL '1 month'
        AND o.status != 'отменен'
    GROUP BY 
        oi.product_id
),
-- CTE 2: Рекурсивный поиск категории 1-го уровня
category_hierarchy AS (
    -- Базовый случай: текущие категории
    SELECT 
        id AS category_id,
        id AS root_category_id,
        name AS root_category_name,
        parent_id,
        level
    FROM 
        categories

    UNION ALL

    -- Рекурсивный случай: поднимаемся к родителям
    SELECT 
        ch.category_id,
        c.id AS root_category_id,
        c.name AS root_category_name,
        c.parent_id,
        c.level
    FROM 
        category_hierarchy ch
        INNER JOIN categories c ON ch.parent_id = c.id
    WHERE 
        ch.level > 1  -- Поднимаемся пока не достигнем уровня 1
),
-- CTE 3: Категории 1-го уровня для товаров
product_level1_category AS (
    SELECT DISTINCT ON (p.id)
        p.id AS product_id,
        p.name AS product_name,
        COALESCE(
            (SELECT root_category_name 
             FROM category_hierarchy ch
             WHERE ch.category_id = pc.category_id 
               AND ch.level = 1
             LIMIT 1),
            c.name  -- Если категория уже 0 или 1 уровня
        ) AS category_level_1
    FROM 
        products p
        INNER JOIN product_categories pc ON p.id = pc.product_id
        INNER JOIN categories c ON pc.category_id = c.id
    WHERE 
        pc.is_primary = TRUE
    ORDER BY 
        p.id
)
SELECT 
    plc.product_name AS "Наименование товара",
    COALESCE(plc.category_level_1, 'Без категории') AS "Категория 1-го уровня",
    rs.total_quantity AS "Общее количество проданных штук"
FROM 
    recent_sales rs
    INNER JOIN product_level1_category plc ON rs.product_id = plc.product_id
ORDER BY 
    rs.total_quantity DESC
LIMIT 5;


-- Запрос для тестирования VIEW
SELECT * FROM top_products_last_month;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2.3.2. АНАЛИЗ И ОПТИМИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════════════════════════

/*
╔══════════════════════════════════════════════════════════════════════════════╗
║ АНАЛИЗ ПРОИЗВОДИТЕЛЬНОСТИ ЗАПРОСА 2.3.1                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

УЗКИЕ МЕСТА (Bottlenecks):

1. Сканирование order_items с фильтрацией по order_date
   - Требует JOIN с orders для каждой строки
   - При тысячах заказов в день - миллионы строк в order_items

2. Рекурсивный поиск категории 1-го уровня
   - Может быть медленным для глубоких иерархий
   - Выполняется для каждого товара

3. Агрегация SUM(quantity) по всем заказам
   - Полное сканирование таблицы order_items

4. JOIN с несколькими таблицами
   - products, product_categories, categories, orders, order_items


╔══════════════════════════════════════════════════════════════════════════════╗
║ ПРЕДЛОЖЕНИЯ ПО ОПТИМИЗАЦИИ                                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
*/

-- ──────────────────────────────────────────────────────────────────────────────
-- ОПТИМИЗАЦИЯ 1: Индексы для ускорения запросов
-- ──────────────────────────────────────────────────────────────────────────────

-- Составной индекс для фильтрации заказов по дате и статусу
CREATE INDEX IF NOT EXISTS idx_orders_date_status 
ON orders(order_date DESC, status) 
WHERE status != 'отменен';

-- Составной индекс для быстрого JOIN order_items с orders
CREATE INDEX IF NOT EXISTS idx_order_items_order_product 
ON order_items(order_id, product_id, quantity);

-- Индекс для поиска основной категории товара
CREATE INDEX IF NOT EXISTS idx_product_categories_primary 
ON product_categories(product_id, category_id) 
WHERE is_primary = TRUE;

-- Индекс для быстрого поиска категорий по уровню
CREATE INDEX IF NOT EXISTS idx_categories_level_parent 
ON categories(level, parent_id, id);


-- ──────────────────────────────────────────────────────────────────────────────
-- ОПТИМИЗАЦИЯ 2: Материализованное представление (Materialized View)
-- Для часто запрашиваемых данных
-- ──────────────────────────────────────────────────────────────────────────────

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_top_products_last_month AS
WITH 
recent_sales AS (
    SELECT 
        oi.product_id,
        SUM(oi.quantity) AS total_quantity
    FROM 
        order_items oi
        INNER JOIN orders o ON oi.order_id = o.id
    WHERE 
        o.order_date >= CURRENT_DATE - INTERVAL '1 month'
        AND o.status != 'отменен'
    GROUP BY 
        oi.product_id
),
product_level1_category AS (
    SELECT DISTINCT ON (p.id)
        p.id AS product_id,
        p.name AS product_name,
        c.name AS category_level_1
    FROM 
        products p
        INNER JOIN product_categories pc ON p.id = pc.product_id
        INNER JOIN categories c ON pc.category_id = c.id
    WHERE 
        pc.is_primary = TRUE
        AND c.level = 1
    ORDER BY 
        p.id
)
SELECT 
    plc.product_name,
    COALESCE(plc.category_level_1, 'Без категории') AS category_level_1,
    rs.total_quantity,
    CURRENT_TIMESTAMP AS last_updated
FROM 
    recent_sales rs
    INNER JOIN product_level1_category plc ON rs.product_id = plc.product_id
ORDER BY 
    rs.total_quantity DESC
LIMIT 5;

-- Индекс для materialized view
CREATE INDEX IF NOT EXISTS idx_mv_top_products_quantity 
ON mv_top_products_last_month(total_quantity DESC);

-- Обновление materialized view (запускать по расписанию)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_products_last_month;


-- ──────────────────────────────────────────────────────────────────────────────
-- ОПТИМИЗАЦИЯ 3: Денормализация - добавление поля category_level1_id в products
-- Избегаем рекурсивных запросов
-- ──────────────────────────────────────────────────────────────────────────────

-- Добавить колонку в таблицу products
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS category_level1_id BIGINT REFERENCES categories(id);

-- Создать индекс
CREATE INDEX IF NOT EXISTS idx_products_category_level1 
ON products(category_level1_id);

-- Заполнить данные (выполнить один раз)
UPDATE products p
SET category_level1_id = (
    SELECT c.id
    FROM product_categories pc
    INNER JOIN categories c ON pc.category_id = c.id
    WHERE pc.product_id = p.id
      AND pc.is_primary = TRUE
      AND c.level = 1
    LIMIT 1
);

-- Оптимизированный запрос с денормализацией
CREATE OR REPLACE VIEW top_products_last_month_optimized AS
SELECT 
    p.name AS "Наименование товара",
    COALESCE(c.name, 'Без категории') AS "Категория 1-го уровня",
    SUM(oi.quantity) AS "Общее количество проданных штук"
FROM 
    order_items oi
    INNER JOIN orders o ON oi.order_id = o.id
    INNER JOIN products p ON oi.product_id = p.id
    LEFT JOIN categories c ON p.category_level1_id = c.id
WHERE 
    o.order_date >= CURRENT_DATE - INTERVAL '1 month'
    AND o.status != 'отменен'
GROUP BY 
    p.id, p.name, c.name
ORDER BY 
    "Общее количество проданных штук" DESC
LIMIT 5;


-- ──────────────────────────────────────────────────────────────────────────────
-- ОПТИМИЗАЦИЯ 4: Партиционирование таблицы orders по дате
-- Для тысяч заказов в день
-- ──────────────────────────────────────────────────────────────────────────────

-- Создать партиционированную таблицу orders
CREATE TABLE orders_partitioned (
    id BIGSERIAL NOT NULL,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id BIGINT NOT NULL REFERENCES customers(id),
    order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivery_date DATE,
    status VARCHAR(50) NOT NULL DEFAULT 'новый',
    total_amount NUMERIC(15,2) DEFAULT 0,
    discount_amount NUMERIC(15,2) DEFAULT 0,
    tax_amount NUMERIC(15,2) DEFAULT 0,
    final_amount NUMERIC(15,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, order_date)
) PARTITION BY RANGE (order_date);

-- Создать партиции по месяцам
CREATE TABLE orders_2025_10 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');

CREATE TABLE orders_2025_11 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

CREATE TABLE orders_2025_12 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

-- Индексы на партициях создаются автоматически
CREATE INDEX idx_orders_part_date_status 
ON orders_partitioned(order_date DESC, status);


-- ──────────────────────────────────────────────────────────────────────────────
-- ОПТИМИЗАЦИЯ 5: Агрегированная таблица для статистики продаж
-- Предварительный расчет метрик
-- ──────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS product_sales_daily (
    product_id BIGINT NOT NULL REFERENCES products(id),
    sale_date DATE NOT NULL,
    total_quantity NUMERIC(15,3) NOT NULL DEFAULT 0,
    total_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    order_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id, sale_date)
);

-- Индексы
CREATE INDEX idx_product_sales_date ON product_sales_daily(sale_date DESC);
CREATE INDEX idx_product_sales_product ON product_sales_daily(product_id);

-- Триггер для автоматического обновления статистики
CREATE OR REPLACE FUNCTION update_product_sales_daily()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO product_sales_daily (product_id, sale_date, total_quantity, total_amount, order_count)
        SELECT 
            NEW.product_id,
            DATE(o.order_date),
            NEW.quantity,
            NEW.line_total,
            1
        FROM orders o
        WHERE o.id = NEW.order_id
        ON CONFLICT (product_id, sale_date)
        DO UPDATE SET
            total_quantity = product_sales_daily.total_quantity + EXCLUDED.total_quantity,
            total_amount = product_sales_daily.total_amount + EXCLUDED.total_amount,
            order_count = product_sales_daily.order_count + 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_product_sales_daily
AFTER INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_product_sales_daily();

-- Оптимизированный запрос с использованием агрегированной таблицы
CREATE OR REPLACE VIEW top_products_last_month_fast AS
SELECT 
    p.name AS "Наименование товара",
    COALESCE(c.name, 'Без категории') AS "Категория 1-го уровня",
    SUM(psd.total_quantity) AS "Общее количество проданных штук"
FROM 
    product_sales_daily psd
    INNER JOIN products p ON psd.product_id = p.id
    LEFT JOIN categories c ON p.category_level1_id = c.id
WHERE 
    psd.sale_date >= CURRENT_DATE - INTERVAL '1 month'
GROUP BY 
    p.id, p.name, c.name
ORDER BY 
    "Общее количество проданных штук" DESC
LIMIT 5;


-- ──────────────────────────────────────────────────────────────────────────────
-- ОПТИМИЗАЦИЯ 6: Кеширование на уровне приложения (Redis)
-- ──────────────────────────────────────────────────────────────────────────────

/*
Кеширование в Redis с TTL 1 час:
- Ключ: "top_products_last_month"
- Значение: JSON с результатами запроса
- Обновление: каждый час или при добавлении новых заказов

Пример псевдокода:
```python
cache_key = "top_products_last_month"
cached_result = redis.get(cache_key)

if cached_result:
    return json.loads(cached_result)
else:
    result = execute_sql_query()
    redis.setex(cache_key, 3600, json.dumps(result))
    return result
```
*/


-- ═══════════════════════════════════════════════════════════════════════════════
-- СРАВНЕНИЕ ПРОИЗВОДИТЕЛЬНОСТИ
-- ═══════════════════════════════════════════════════════════════════════════════

-- Анализ плана выполнения оригинального запроса
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM top_products_last_month;

-- Анализ плана выполнения оптимизированного запроса
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM top_products_last_month_optimized;

-- Анализ плана с агрегированной таблицей
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM top_products_last_month_fast;


-- ═══════════════════════════════════════════════════════════════════════════════
-- ИТОГОВАЯ ТАБЛИЦА СРАВНЕНИЯ МЕТОДОВ ОПТИМИЗАЦИИ
-- ═══════════════════════════════════════════════════════════════════════════════

/*
┌────────────────────────────┬─────────────────┬───────────────┬──────────────┐
│ Метод оптимизации          │ Сложность       │ Ускорение     │ Рекомендация │
│                            │ внедрения       │               │              │
├────────────────────────────┼─────────────────┼───────────────┼──────────────┤
│ 1. Индексы                 │ Низкая          │ 2-5x          │ ОБЯЗАТЕЛЬНО  │
│ 2. Materialized View       │ Низкая          │ 10-20x        │ ДА           │
│ 3. Денормализация          │ Средняя         │ 5-10x         │ ДА           │
│ 4. Партиционирование       │ Высокая         │ 3-7x          │ При росте    │
│ 5. Агрегированная таблица  │ Высокая         │ 50-100x       │ Для больших  │
│                            │                 │               │ нагрузок     │
│ 6. Кеширование (Redis)     │ Средняя         │ 100-1000x     │ ДА           │
└────────────────────────────┴─────────────────┴───────────────┴──────────────┘

РЕКОМЕНДУЕМЫЙ ПЛАН ВНЕДРЕНИЯ:

Этап 1 (Сейчас):
  ✓ Добавить все индексы (Оптимизация 1)
  ✓ Создать materialized view с обновлением раз в час (Оптимизация 2)

Этап 2 (При росте до 100+ заказов/день):
  ✓ Денормализация category_level1_id (Оптимизация 3)
  ✓ Кеширование в Redis (Оптимизация 6)

Этап 3 (При росте до 1000+ заказов/день):
  ✓ Партиционирование orders (Оптимизация 4)
  ✓ Агрегированная таблица product_sales_daily (Оптимизация 5)

ОЖИДАЕМЫЙ РЕЗУЛЬТАТ:
  - Снижение времени выполнения запроса с 500ms до 5-10ms
  - Масштабируемость до миллионов заказов
  - Стабильная производительность при росте данных
*/
