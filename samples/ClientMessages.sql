CREATE OR REPLACE FUNCTION raise_func(text)
  RETURNS void LANGUAGE plpgsql AS
$BODY$ 
BEGIN 
   RAISE NOTICE '%', $1; 
END; 
$BODY$;

WITH 
sql_task(id) AS (
    INSERT INTO timetable.command VALUES (
        DEFAULT,                        -- command_id
        'raise client message',         -- name
        DEFAULT,                        -- 'SQL' :: timetable.command_kind
        'SELECT raise_func($1)'     -- task script
    )
    RETURNING command_id
),
chain_insert(task_id) AS (
    INSERT INTO timetable.task 
        (task_id, parent_id, command_id, run_as, database_connection, ignore_error)
    VALUES 
        (DEFAULT, NULL, (SELECT id FROM sql_task), NULL, NULL, TRUE)
    RETURNING task_id
),
chain_config(id) as (
    INSERT INTO timetable.chain (
        chain_id, 
        task_id, 
        chain_name, 
        run_at, 
        max_instances, 
        live,
        self_destruct, 
        exclusive_execution
    )  VALUES (
        DEFAULT, -- chain_id, 
        (SELECT task_id FROM chain_insert), -- task_id, 
        'raise client message every minute', -- chain_name, 
        '* * * * *', -- run_at, 
        1, -- max_instances, 
        TRUE, -- live, 
        FALSE, -- self_destruct,
        FALSE -- exclusive_execution, 
    )
    RETURNING  chain_id
)
INSERT INTO timetable.parameter 
    (chain_id, task_id, order_id, value)
VALUES (
    (SELECT id FROM chain_config),
    (SELECT task_id FROM chain_insert),
    1,
    '[ "Hey from client messages task" ]' :: jsonb) 