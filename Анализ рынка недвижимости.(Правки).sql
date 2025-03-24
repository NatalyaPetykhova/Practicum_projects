/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Петухова Наталья
 * Дата: 31.10.2024
*/

-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Получаем все поля, которые не содержат выбросы:
filtered_fields AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
),
-- В этом запросе группируем данные по категориям.
group_category AS (
SELECT a.id,
--Группируем данные по категории "Регион":
	CASE
		WHEN f.city_id = '6X8I' THEN 'Санкт-Петербург'
		ELSE 'ЛенОбл'
	END AS category_city,
--Группируем данные по категории "Активность объявлений":
	CASE
		WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'Месяц'
		WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'Квартал'
		WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'Полгода'
		WHEN a.days_exposition >= 181 THEN 'Больше полугода' 
		WHEN a.days_exposition IS NULL THEN 'Нет данных'
	END AS category_time_advert
FROM real_estate.flats AS f
JOIN real_estate.advertisement AS a USING(id)
GROUP by a.id,
	category_city, 
	category_time_advert
)	
SELECT 
	category_city,
	category_time_advert,
	ROUND(AVG((a.last_price / f.total_area)::numeric)) AS avg_cost_square_meter, -- средняя стоимость одного квадратного метра
	COUNT(DISTINCT a.id) AS count_ads, --количество объявлений
	ROUND((COUNT(a.id)::numeric / SUM(COUNT(a.id)) OVER (PARTITION BY category_city)*100), 2) AS pers_ads, --доля объявлений в разрезе категорий
	ROUND(AVG((f.total_area)::numeric), 2) AS avg_lotal_area, --средняя площадь квартиры
	ROUND(AVG((a.last_price)::numeric)) AS avg_last_price, --средняя стоимость квартиры
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms) as median_count_rooms, --медиана количество комнат в квартире
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) as median_count_balcony, -- медиана количество балконов в квартире
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.floor) as median_count_floor -- медиана этажности
FROM real_estate.advertisement AS a
	JOIN real_estate.flats AS f ON a.id = f.id
	JOIN filtered_fields AS ff ON f.id = ff.id 
	JOIN real_estate.type AS t ON f.type_id = t.type_id  
	JOIN group_category AS gc ON a.id = gc.id
WHERE t.type = 'город'
AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31' 
GROUP by --группируем по категории "Регион" и "Активность объявлений"
	category_city, 
	category_time_advert
ORDER BY
	category_city DESC

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY total_area) AS total_area_limit_l,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats as f
    JOIN real_estate.advertisement AS a USING(id)
),
-- Получаем все поля, которые не содержат выбросы:
filtered_fields AS(
    SELECT a.id
    FROM real_estate.flats as f  
    JOIN real_estate.advertisement AS a USING(id)
    WHERE 
        total_area < (SELECT total_area_limit_h FROM limits) 
        AND total_area > (SELECT total_area_limit_l FROM limits)
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    ),    
count_ads_published AS (
    SELECT 
    	EXTRACT(MONTH FROM a.first_day_exposition) AS published_month, -- выделяем номер месяца из даты публикации объявления
        COUNT(a.id) AS count_published_ads, -- считаем количество опубликованных объявлений
        ROUND(AVG(a.last_price / f.total_area)::numeric) AS avg_cost_square_meter_published, -- Средняя стоимость квадратного метра для опубликованных объявлений
        ROUND((AVG(f.total_area)::numeric), 2) AS avg_area_published --средняя площадь квартир в объявлениях, которые опубликованы
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    JOIN filtered_fields AS ff ON f.id = ff.id 
    JOIN real_estate.type as t on f.type_id = t.type_id
    WHERE a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31' 
    AND t.type = 'город'
    GROUP by published_month--группируем по месяцу публикации	
    ORDER BY published_month--сортируем по месяцу публикации  	 
),
count_ads_removed AS (
    SELECT 
    	EXTRACT(MONTH FROM a.first_day_exposition + days_exposition * INTERVAL '1 day') AS removed_month, -- выделяем номер месяца из даты снятия объявления
        COUNT(a.id) AS count_removed_ads, -- считаем количество снятых объявлений
        ROUND(((COUNT(a.id)::NUMERIC) *100 / (SELECT COUNT(*) FROM filtered_fields)), 2) AS pers_count_removed_ads, --доля снятых объявлений от общего количества
        ROUND(AVG(a.last_price / f.total_area)::numeric) AS avg_cost_square_meter_removed, -- Средняя стоимость квадратного метра для снятых объявлений
        ROUND((AVG(f.total_area)::numeric), 2) AS avg_area_removed --средняя площадь квартир в объявлениях, которые были сняты
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    JOIN filtered_fields AS ff ON f.id = ff.id 
    JOIN real_estate.type as t on f.type_id = t.type_id
    WHERE a.days_exposition IS NOT NULL
    AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31' 
    AND t.type = 'город'
    GROUP by removed_month--группируем по месяцу снятия	
    ORDER BY removed_month--сортируем по месяцу снятия  	
    )
SELECT 
	CASE 
		WHEN cap.published_month = 1 THEN 'Январь'
		WHEN cap.published_month = 2 THEN 'Февраль'
		WHEN cap.published_month = 3 THEN 'Март'
		WHEN cap.published_month = 4 THEN 'Апрель'
		WHEN cap.published_month = 5 THEN 'Май'
		WHEN cap.published_month = 6 THEN 'Июнь'
		WHEN cap.published_month = 7 THEN 'Июль'
		WHEN cap.published_month = 8 THEN 'Август'
		WHEN cap.published_month = 9 THEN 'Сентябрь'
		WHEN cap.published_month = 10 THEN 'Октябрь'
		WHEN cap.published_month = 11 THEN 'Ноябрь'
		WHEN cap.published_month = 12 THEN 'Декабрь'
	END, --месяц даты публикации объявления	
    cap.count_published_ads, --количество опубликованных объявлений
    car.count_removed_ads, --количество снятых объявлений
--Для того, чтобы посмотреть, в какие месяцы наблюдается наибольшая активность в публикации и в снятии объявлений, используем оконную функцию ранжирования.
--Сортируем по убыванию, таким образом Ранг 1 - высокая активность, ранг 12 - низкая активность.    
    RANK() OVER (ORDER BY count_published_ads DESC) AS rank_published,--rank_published, --ранг активности опубликованных объявлений
    RANK() OVER (ORDER BY count_removed_ads DESC) AS rank_removed,--rank_removed, --ранг актирности снятых с продажи объявлений
    car.pers_count_removed_ads,--доля снятых объявлений от общего количества
    cap.avg_cost_square_meter_published, --Средняя стоимость квадратного метра для опубликованных объявлений
    car.avg_cost_square_meter_removed, --Средняя стоимость квадратного метра для снятых объявлений 
    cap.avg_area_published, --средняя площадь квартир в объявлениях, которые опубликованы
    car.avg_area_removed --средняя площадь квартир в объявлениях, которые сняты с продажи
FROM count_ads_published AS cap 
JOIN count_ads_removed AS car ON cap.published_month = car.removed_month
ORDER BY cap.published_month --сортируем по месяцу публикации объявлений

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Получаем все поля, которые не содержат выбросы:
filtered_fields AS (
    SELECT id
    FROM real_estate.flats  AS f
    JOIN real_estate.city AS c ON f.city_id = c.city_id  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND c.city_id <> '6X8I' 
),
advertisement_data AS (
     SELECT 
        c.city_id,
        ROUND((AVG(a.days_exposition)::numeric), 2) AS avg_days_exposition, --средняя длительность нахождения объявления на сайте
        COUNT(a.id) AS total_count_ads,-- количество опубликованных объявлений
        SUM(CASE WHEN a.days_exposition IS NOT NULL THEN 1 ELSE 0 END) AS count_removed_ads, --количество снятых объявлений
        ROUND((SUM(CASE WHEN a.days_exposition IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(a.id)), 2) AS perc_removed_ads, --доля снятых объявлений
        ROUND((AVG(a.last_price) / AVG(f.total_area))::numeric, 2) AS avg_cost_square_meter, --средняя стоимость квадратного метра
		ROUND((AVG(f.total_area)::numeric), 2) AS avg_area, --средняя площадь квартир
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms) as median_count_rooms, --медиана количество комнат в квартире
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) as median_count_balcony, -- медиана количество балконов в квартире
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.floor) as median_count_floor, -- медиана этажности
		ROUND(AVG(f.ceiling_height)::numeric, 1) AS avg_ceiling_height, --средняя высота потолков
		(SELECT NTILE(4) OVER(ORDER BY avg_days_exposition) FROM (SELECT AVG(days_exposition) AS avg_days_exposition FROM real_estate.advertisement ) AS rank) AS rank_active --ранг активности объявлений
	FROM real_estate.advertisement AS a
	JOIN real_estate.flats AS f ON a.id = f.id
	JOIN filtered_fields AS ff ON f.id = ff.id 
	JOIN real_estate.city AS c ON f.city_id = c.city_id   
	WHERE a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'  -- Условие для фильтрации по дате
	GROUP BY c.city_id
	HAVING COUNT(a.id) > 20
)
SELECT 
    c.city,
    ad.total_count_ads, --количество опубликованных объявлений
    ad.count_removed_ads, --количество снятых объявлений
    ad.perc_removed_ads, --доля снятых объявлений
    ad.avg_days_exposition, --средняя длительность нахождения объявления на сайте
    ad.avg_cost_square_meter,--средняя стоимость квадратного метра
    ad.avg_area, --средняя площадь квартир
    ad.median_count_rooms, --медиана количества комнат в квартире
    ad.median_count_balcony, -- медиана количество балконов в квартире
    ad.median_count_floor, -- медиана этажности
    ad.avg_ceiling_height, --средняя высота потолков
--Ранжирование было проведено по всем населенным пунктам, в том числе не вошедших в топ. 
--В запросе применена сортировка длительности нахождения объявления на сайте по возрастанию, 
--поэтому все населенные пункты получили ранг – 1.
    ad.rank_active -- ранг активности по средней длительности нахождения объявления на сайте
FROM advertisement_data AS ad 
JOIN real_estate.city AS c ON ad.city_id = c.city_id
ORDER BY ad.avg_days_exposition
LIMIT 15
           
    

