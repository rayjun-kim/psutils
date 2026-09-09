```sql
WITH target_list (schema_name, table_name) AS (
  VALUES
    ('SCHEMA1', 'TABLE1'),
    ('SCHEMA1', 'TABLE2'),
    ('SCHEMA2', 'TABLE3')
),
my_groups (grp) AS (
  SELECT GROUP_PROFILE_NAME
    FROM QSYS2.GROUP_PROFILE_ENTRIES
   WHERE USER_PROFILE_NAME = CURRENT_USER
)
SELECT
  t.schema_name,
  t.table_name,
  CASE WHEN s.TABLE_NAME IS NULL THEN 'N' ELSE 'Y' END AS table_exists,
  CASE
    WHEN s.TABLE_NAME IS NULL THEN 'N/A'
    WHEN (SELECT COUNT(*) FROM QSYS2.USER_INFO u
           WHERE u.AUTHORIZATION_NAME = CURRENT_USER
             AND u.SPECIAL_AUTHORITIES LIKE '%*ALLOBJ%') > 0
      THEN 'Y'
    WHEN (SELECT COUNT(*)
            FROM TABLE(QSYS2.OBJECT_PRIVILEGES(
                   s.SYSTEM_TABLE_SCHEMA, s.SYSTEM_TABLE_NAME, '*FILE')) p
           WHERE p.DATA_READ = 'YES'
             AND (p.AUTHORIZATION_USER = CURRENT_USER
                  OR p.AUTHORIZATION_USER = '*PUBLIC'
                  OR p.AUTHORIZATION_USER IN (SELECT grp FROM my_groups))
         ) > 0
      THEN 'Y'
    ELSE 'N'
  END AS can_read,
  s.TABLE_TYPE,
  s.TABLE_OWNER
FROM target_list t
LEFT JOIN QSYS2.SYSTABLES s
  ON s.TABLE_SCHEMA = t.schema_name
 AND s.TABLE_NAME   = t.table_name
ORDER BY t.schema_name, t.table_name;
```
