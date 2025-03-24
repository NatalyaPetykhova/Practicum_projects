/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Петухова Наталья 
 * Дата: 21.10.2024г.
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:

SELECT COUNT(DISTINCT id) AS count_id, --общее количество игроков
 	   SUM(payer) AS count_payer, --количество платящих игроков
 	   SUM(payer)::REAL / COUNT(id) * 100 AS avg_payer -- доля платящих игроков от общего количества пользователей
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа.

SELECT r.race,
	   SUM(u.payer) AS count_payer, --количество платящих игроков в разрезе рассы
	   COUNT(DISTINCT u.id) AS count_id,--общее количество игроков в разрезе рассы
	   SUM(u.payer)::REAL / COUNT(DISTINCT u.id) * 100 AS avg_payer	  -- доля платящих игроков от общего количества пользователей в разрезе рассы
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT COUNT(transaction_id) AS count_events, --общее количество покупок
		SUM(amount) AS sum_amount, -- общая сумма покупок
		MIN(amount) AS min_amount, -- минимальная стоимость покупки
		MAX(amount) AS max_amount, --максимальная стоимость покупки
		AVG(amount) AS avg_amount, -- средняя стоимость покупки
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount), -- медиана
		STDDEV(amount) AS ctd_amount --стандартное отклонение стоимости покупки
FROM fantasy.events
WHERE amount > 0; --исключаем нулевые покупки

-- 2.2: Аномальные нулевые покупки:

SELECT COUNT(transaction_id) AS count_zero_events, --считаем количество покупок с нулевой стоимостью
       COUNT(transaction_id)::real / (SELECT COUNT(*) FROM fantasy.events) * 100 AS cost_count_events -- рассчитываем долю покупок с нулевой стоимостью от общего числа покупок.
FROM fantasy.events
WHERE amount = 0; --фильтруем записи, чтобы учитывать только те, у которых стоимость равна нулю	   

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

SELECT CASE 
       WHEN u.payer > 0 THEN 'Платящие'
       ELSE 'Не платящие'
       END AS group_players, -- определяем "платящий" игрок или нет
       COUNT(DISTINCT u.id) AS count_players,--считаем общее количество игроков в каждой группе, группу определяем с помощью конструкции CASE
       AVG(count_events) AS avg_count_events,--считаем среднее количество покупок в каждой группе игроков
       AVG(sum_amount) AS avg_sum_amount --считаем среднюю сумму покупки для каждой группы игроков
FROM  fantasy.users AS u
LEFT JOIN (
SELECT e.id,
       COUNT(e.transaction_id) AS count_events, --считаем количество покупок, для каждого игрока ипользуем группировку по id
       SUM(e.amount) AS sum_amount --считаем суммарную стоимость покупок, для каждого игрока ипользуем группировку по id
FROM fantasy.events AS e
WHERE e.amount > 0 -- исключаем нулевые покупки
GROUP BY e.id
) AS e ON u.id = e.id
GROUP BY group_players;

-- 2.4: Популярные эпические предметы:
WITH count_events AS (
SELECT i.game_items,
	   COUNT(e.transaction_id) AS count_events, --количество продаж эпических предметов
       COUNT(e.transaction_id) / (SELECT COUNT(transaction_id)::real FROM fantasy.events) *100 AS perc_count_events --доля продаж эпического предмета от общего количества продаж
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i ON e.item_code = i.item_code
GROUP BY i.game_items
),
count_sales_player AS (
SELECT i.game_items,
       COUNT(DISTINCT e.id) / (SELECT COUNT(DISTINCT id)::real FROM fantasy.events) *100 AS perc_player ----доля игроков купивших эпический предмет
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i ON e.item_code = i.item_code
WHERE e.amount > 0 --исключаем нулувые покупки
GROUP BY i.game_items
)
SELECT i.game_items,
        ce.count_events, --колисество продаж эпических предметов
		ce.perc_count_events, --доля продаж эпического предмета от общего количества продаж
		csp.perc_player --доля игроков купивших эпический предмет
FROM fantasy.items AS i
LEFT JOIN count_events AS ce ON i.game_items = ce.game_items
LEFT JOIN count_sales_player AS csp ON i.game_items = csp.game_items	
WHERE ce.count_events IS NOT NULL
ORDER BY csp.perc_player DESC; --выполняем состировку по количеству продаж эпических предметов, сортируем по убыванию, чтобы увидеть самые популяные эпические предметы

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:

WITH race_plaers AS (
SELECT r.race,
       COUNT(DISTINCT u.id) AS count_players,--общее количество игроков в разрезе рассы персонажа
       SUM(u.payer) AS sum_payer_players --количество платящих игроков в разрезе рассы
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race_id 
),
count_players AS (
SELECT r.race,
       COUNT(DISTINCT u.id) AS count_players_events, --количество игроков которые совершают внутриигровые покупки
       COUNT(DISTINCT u.id) / (SELECT COUNT(DISTINCT id)::real FROM fantasy.users) * 100 AS perc_players_events --доля игроков которые совершают внутриигровые покупки
FROM fantasy.users AS u
JOIN fantasy.events AS e USING(id)
JOIN fantasy.race AS r USING(race_id)
WHERE e.amount > 0
GROUP BY r.race_id 
),
avg_cost_amount AS (
SELECT r.race,
       COUNT(e.transaction_id)::float/ COUNT(DISTINCT e.id) AS avg_count_events,  --среднее количество покупок на одного игрока
       AVG(e.amount) AS avg_cost, --средняя стоимость одной покупки одного игрока
       SUM(e.amount) / COUNT(DISTINCT e.id) AS avg_sum_amount  --средняя сумма всех покупок одного игрока  
FROM fantasy.events AS e
JOIN fantasy.users AS u USING(id)
JOIN fantasy.race AS r USING(race_id)
WHERE amount > 0
GROUP BY  r.race_id
)
SELECT r.race,
        rp.count_players, --общее количество игроков в разрезе рассы персонажа
		rp.sum_payer_players, ----количество платящих игроков в разрезе рассы
		cp.count_players_events,--количество игроков которые совершают внутриигровые покупки
		cp.perc_players_events,--доля платящих игроков
		asa.avg_count_events,--среднее количество покупок на одного игрока
		asa.avg_cost,--средняя стоимость одной покупки одного игрока
		asa.avg_sum_amount --средняя сумма всех покупок одного игрока  
FROM fantasy.race AS r
JOIN race_plaers AS rp ON r.race = rp.race
JOIN count_players AS cp ON rp.race = cp.race
JOIN avg_cost_amount AS asa ON cp.race = asa.race;



-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь
