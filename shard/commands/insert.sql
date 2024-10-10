INSERT INTO company_db.events_distr
SELECT
    now(),
    rand(1),                               -- Random unique identifier
    if(rand() % 2 = 0, 'view', 'contact')   -- Random event type: either 'view' or 'contact'
FROM numbers(3);                          -- Number of rows to generate (10 in this case)

SELECT * FROM company_db.events_distr SETTINGS skip_unavailable_shards=1;