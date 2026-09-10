## mapping
```yaml
# ============================================================
# DB2 for i -> EPAS (Oracle-compatible types) type mapping
# ============================================================
# Data only (no SQL) - the queries that use this data live in
# this directory's .hpl files. {length}/{scale} are substituted
# from the source catalog query at run time. Lookup precedence
# (see migrate_table.hpl): overrides (config.yaml) > UDT name >
# resolved type (with _FOR_BIT_DATA suffix where applicable) >
# TEXT default.
#
# Targets EPAS's Oracle-compatible type set (VARCHAR2/NUMBER/RAW/
# NCHAR/NVARCHAR2/CLOB/BLOB/NCLOB/XMLTYPE) instead of native
# Postgres types (VARCHAR/NUMERIC/BYTEA/TEXT/XML) - these are
# built into EPAS itself, not something the target database/role
# needs enabled first. Chosen to match a specific CASE-expression
# type mapping used by a prior tool, so the two migrate identically.
# ============================================================
mapping:
  SMALLINT: SMALLINT
  INTEGER: INTEGER
  INT: INTEGER
  BIGINT: BIGINT
  DECIMAL: "NUMBER({length},{scale})"
  DEC: "NUMBER({length},{scale})"
  NUMERIC: "NUMBER({length},{scale})"

  # DECFLOAT/16/34 have no fixed precision/scale to carry into
  # NUMBER({length},{scale}) (DB2 for i reports none for them), so
  # they map to bare NUMBER, matching the reference mapping.
  DECFLOAT: NUMBER
  DECFLOAT16: NUMBER
  DECFLOAT34: NUMBER

  # REAL/FLOAT -> FLOAT, DOUBLE -> DOUBLE PRECISION: kept distinct
  # (not both DOUBLE PRECISION) to match the reference mapping
  # exactly, even though EPAS's FLOAT is itself just an alias.
  REAL: FLOAT
  FLOAT: FLOAT
  DOUBLE: "DOUBLE PRECISION"

  CHARACTER: "CHAR({length})"
  CHAR: "CHAR({length})"
  VARCHAR: "VARCHAR2({length})"
  GRAPHIC: "NCHAR({length})"
  VARGRAPHIC: "NVARCHAR2({length})"
  VARG: "NVARCHAR2({length})"   # abbreviated catalog form of VARGRAPHIC

  "LONG VARCHAR": CLOB
  "LONG VARG": NCLOB
  "LONG VARGRAPHIC": NCLOB
  CLOB: CLOB
  DBCLOB: CLOB
  BLOB: BLOB

  DATE: DATE
  TIME: TIME
  TIMESTAMP: TIMESTAMP
  TIMESTMP: TIMESTAMP        # abbreviated catalog form of TIMESTAMP

  BINARY: "RAW({length})"
  VARBINARY: "RAW({length})"
  VARBIN: "RAW({length})"      # abbreviated catalog form of VARBINARY

  # FOR BIT DATA variants (CCSID 65535) of the character types
  # above - see COL_CCSID note in migrate_table.hpl. Still BYTEA
  # (not RAW/BLOB): these columns hold arbitrary binary content DB2
  # only catalogs as character types, and the reference mapping's
  # own CCSID=65535 branches (VARCHAR/CHARACTER/CHAR only) agree on
  # BYTEA - carried over unchanged, and extended to GRAPHIC/
  # VARGRAPHIC for consistency since eligibleForBitData below covers
  # those too.
  CHARACTER_FOR_BIT_DATA: BYTEA
  CHAR_FOR_BIT_DATA: BYTEA
  VARCHAR_FOR_BIT_DATA: BYTEA
  GRAPHIC_FOR_BIT_DATA: BYTEA
  VARGRAPHIC_FOR_BIT_DATA: BYTEA

  ROWID: "VARCHAR2(100)"
  DATALINK: "VARCHAR2(255)"
  XML: XMLTYPE
  BOOLEAN: BOOLEAN

  # Example user-defined distinct type mappings. Add one entry per
  # UDT name to control its target type explicitly; any UDT not
  # listed here still migrates correctly via its resolved base type
  # above (this tool's DISTINCT handling - see migrate_table.hpl -
  # differs from the reference mapping's own DISTINCT branch, which
  # instead emits a quoted, lowercased custom type name and assumes
  # a matching type/domain already exists on the target; add an
  # entry per UDT here instead of relying on that).
  US_DOLLAR: "NUMBER({length},{scale})"
  MONEY: "NUMBER({length},{scale})"
  EMAIL_ADDR: "VARCHAR2({length})"
  EMAILADDR: "VARCHAR2({length})"

# Postgres partitions use an exclusive upper bound (FOR VALUES
# FROM (x) TO (y), y exclusive), while DB2 for i range partitions
# report an inclusive upper bound. Converting between the two
# requires "the value after y", which is only well-defined for
# a limited set of types. Range partition keys of any other type
# fall back to an unpartitioned (flat) target table, with a log
# message.
range_boundary_supported_types: [DATE, INTEGER]
```

### PG mode
```yaml
mapping:
  SMALLINT: INTEGER
  INTEGER: INTEGER
  INT: INTEGER
  BIGINT: BIGINT
  DECIMAL: "NUMERIC({length},{scale})"
  DEC: "NUMERIC({length},{scale})"
  NUMERIC: "NUMERIC({length},{scale})"

  DECFLOAT: TEXT
  DECFLOAT16: TEXT
  DECFLOAT34: TEXT

  REAL: "DOUBLE PRECISION"
  FLOAT: "DOUBLE PRECISION"
  DOUBLE: "DOUBLE PRECISION"

  CHARACTER: "CHAR({length})"
  CHAR: "CHAR({length})"
  VARCHAR: "VARCHAR({length})"
  GRAPHIC: "CHAR({length})"
  VARGRAPHIC: "VARCHAR({length})"
  VARG: "VARCHAR({length})"

  "LONG VARCHAR": TEXT
  "LONG VARG": TEXT
  "LONG VARGRAPHIC": TEXT
  CLOB: TEXT
  DBCLOB: TEXT
  BLOB: BYTEA

  DATE: DATE
  TIME: TIME
  TIMESTAMP: TIMESTAMP
  TIMESTMP: TIMESTAMP

  BINARY: BYTEA
  VARBINARY: BYTEA
  VARBIN: BYTEA

  CHARACTER_FOR_BIT_DATA: BYTEA
  CHAR_FOR_BIT_DATA: BYTEA
  VARCHAR_FOR_BIT_DATA: BYTEA
  GRAPHIC_FOR_BIT_DATA: BYTEA
  VARGRAPHIC_FOR_BIT_DATA: BYTEA

  ROWID: TEXT
  DATALINK: TEXT
  XML: XML
  BOOLEAN: BOOLEAN

  US_DOLLAR: "NUMERIC({length},{scale})"
  MONEY: "NUMERIC({length},{scale})"
  EMAIL_ADDR: "VARCHAR({length})"
  EMAILADDR: "VARCHAR({length})"

range_boundary_supported_types: [DATE, INTEGER]
```

# mapping table
## 오라클 모드 (VARCHAR2/NUMBER/RAW 등)

| DB2 for i | EPAS |
|---|---|
| SMALLINT | SMALLINT |
| INTEGER / INT | INTEGER |
| BIGINT | BIGINT |
| DECIMAL / DEC / NUMERIC | NUMBER({length},{scale}) |
| DECFLOAT / DECFLOAT16 / DECFLOAT34 | NUMBER |
| REAL / FLOAT | FLOAT |
| DOUBLE | DOUBLE PRECISION |
| CHARACTER / CHAR | CHAR({length}) |
| VARCHAR | VARCHAR2({length}) |
| GRAPHIC | NCHAR({length}) |
| VARGRAPHIC / VARG | NVARCHAR2({length}) |
| LONG VARCHAR | CLOB |
| LONG VARG / LONG VARGRAPHIC | NCLOB |
| CLOB / DBCLOB | CLOB |
| BLOB | BLOB |
| DATE | DATE |
| TIME | TIME |
| TIMESTAMP / TIMESTMP | TIMESTAMP |
| BINARY / VARBINARY / VARBIN | RAW({length}) |
| CHARACTER/CHAR/VARCHAR/GRAPHIC/VARGRAPHIC (CCSID 65535, FOR BIT DATA) | BYTEA |
| ROWID | VARCHAR2(100) |
| DATALINK | VARCHAR2(255) |
| XML | XMLTYPE |
| BOOLEAN | BOOLEAN |
| DISTINCT (UDT, 예: US_DOLLAR/MONEY) | NUMBER({length},{scale}) |
| DISTINCT (UDT, 예: EMAIL_ADDR) | VARCHAR2({length}) |

## PG 모드 (네이티브 Postgres)

| DB2 for i | EPAS |
|---|---|
| SMALLINT | INTEGER |
| INTEGER / INT | INTEGER |
| BIGINT | BIGINT |
| DECIMAL / DEC / NUMERIC | NUMERIC({length},{scale}) |
| DECFLOAT / DECFLOAT16 / DECFLOAT34 | TEXT |
| REAL / FLOAT / DOUBLE | DOUBLE PRECISION |
| CHARACTER / CHAR | CHAR({length}) |
| VARCHAR | VARCHAR({length}) |
| GRAPHIC | CHAR({length}) |
| VARGRAPHIC / VARG | VARCHAR({length}) |
| LONG VARCHAR / LONG VARG / LONG VARGRAPHIC | TEXT |
| CLOB / DBCLOB | TEXT |
| BLOB | BYTEA |
| DATE | DATE |
| TIME | TIME |
| TIMESTAMP / TIMESTMP | TIMESTAMP |
| BINARY / VARBINARY / VARBIN | BYTEA |
| CHARACTER/CHAR/VARCHAR/GRAPHIC/VARGRAPHIC (CCSID 65535, FOR BIT DATA) | BYTEA |
| ROWID / DATALINK | TEXT |
| XML | XML |
| BOOLEAN | BOOLEAN |
| DISTINCT (UDT, 예: US_DOLLAR/MONEY) | NUMERIC({length},{scale}) |
| DISTINCT (UDT, 예: EMAIL_ADDR) | VARCHAR({length}) |




```sql
CASE UPPER(TRIM(COALESCE(TYP.SOURCE_TYPE, C.DATA_TYPE))) " +
                "WHEN 'VARCHAR' THEN CASE WHEN C.CCSID = 65535 THEN 'BYTEA' ELSE 'VARCHAR2(' || C.LENGTH || ')' END " +
                "WHEN 'CHARACTER' THEN CASE WHEN C.CCSID = 65535 THEN 'BYTEA' ELSE 'CHAR(' || C.LENGTH || ')' END " +
                "WHEN 'CHAR' THEN CASE WHEN C.CCSID = 65535 THEN 'BYTEA' ELSE 'CHAR(' || C.LENGTH || ')' END " +
                "WHEN 'VARGRAPHIC' THEN 'NVARCHAR2(' || C.LENGTH || ')' " +
                "WHEN 'VARG' THEN 'NVARCHAR2(' || C.LENGTH || ')' " +
                "WHEN 'GRAPHIC' THEN 'NCHAR(' || C.LENGTH || ')' " +
                "WHEN 'SMALLINT' THEN 'SMALLINT' " +
                "WHEN 'INTEGER' THEN 'INTEGER' " +
                "WHEN 'BIGINT' THEN 'BIGINT' " +
                "WHEN 'DECIMAL' THEN 'NUMBER(' || C.LENGTH || ',' || COALESCE(C.NUMERIC_SCALE, 0) || ')' " +
                "WHEN 'NUMERIC' THEN 'NUMBER(' || C.LENGTH || ',' || COALESCE(C.NUMERIC_SCALE, 0) || ')' " +
                "WHEN 'DECFLOAT' THEN 'NUMBER' " +
                "WHEN 'DECFLOAT16' THEN 'NUMBER' " +
                "WHEN 'DECFLOAT34' THEN 'NUMBER' " +
                "WHEN 'REAL' THEN 'FLOAT' " +
                "WHEN 'FLOAT' THEN 'FLOAT' " +
                "WHEN 'DOUBLE' THEN 'DOUBLE PRECISION' " +
                "WHEN 'BOOLEAN' THEN 'BOOLEAN' " +
                "WHEN 'DATE' THEN 'DATE' " +
                "WHEN 'TIME' THEN 'TIME' " +
                "WHEN 'TIMESTAMP' THEN 'TIMESTAMP' " +
                "WHEN 'TIMESTMP' THEN 'TIMESTAMP' " +
                "WHEN 'BINARY' THEN 'RAW(' || C.LENGTH || ')' " +
                "WHEN 'VARBINARY' THEN 'RAW(' || C.LENGTH || ')' " +
                "WHEN 'VARBIN' THEN 'RAW(' || C.LENGTH || ')' " +
                "WHEN 'LONG VARCHAR' THEN 'CLOB' " +
                "WHEN 'LONG VARG' THEN 'NCLOB' " +
                "WHEN 'LONG VARGRAPHIC' THEN 'NCLOB' " +
                "WHEN 'CLOB' THEN 'CLOB' " +
                "WHEN 'BLOB' THEN 'BLOB' " +
                "WHEN 'DBCLOB' THEN 'CLOB' " +
                "WHEN 'XML' THEN 'XMLTYPE' " +
                "WHEN 'ROWID' THEN 'VARCHAR2(100)' " +
                "WHEN 'DATALINK' THEN 'VARCHAR2(255)' " +
                "WHEN 'DISTINCT' THEN '\"' || LOWER(TRIM(COALESCE(TYP.USER_DEFINED_TYPE_NAME, C.USER_DEFINED_TYPE_NAME))) || '\"' " +
                "ELSE TRIM(COALESCE(TYP.SOURCE_TYPE, C.DATA_TYPE)) END
```

분류|원본 데이터 타입 (Source)|조건 (Condition)|변환 데이터 타입 (Target)|비고
-|-|-|-|-
문자형|VARCHAR|CCSID = 65535|BYTEA|이진 데이터 처리
문자형|-|그 외|VARCHAR2(LENGTH)|
문자형|CHARACTER / CHAR|CCSID = 65535|BYTEA|이진 데이터 처리
문자형|-|그 외|CHAR(LENGTH)|
문자형|VARGRAPHIC / VARG|-|NVARCHAR2(LENGTH)|다국어(유니코드) 가변 문자열
문자형|GRAPHIC|-|NCHAR(LENGTH)|다국어(유니코드) 고정 문자열
숫자형|SMALLINT|-|SMALLINT|정수
숫자형|INTEGER|-|INTEGER|정수
숫자형|BIGINT|-|BIGINT|정수
숫자형|DECIMAL / NUMERIC|-|"NUMBER(LENGTH| SCALE)"|SCALE이 없으면 0 처리
숫자형|DECFLOAT / DECFLOAT16 / DECFLOAT34|-|NUMBER|십진 부동소수점
숫자형|REAL / FLOAT|-|FLOAT|부동소수점
숫자형|DOUBLE|-|DOUBLE PRECISION|배정밀도 부동소수점
논리형|BOOLEAN|-|BOOLEAN|참/거짓
날짜/시간형|DATE|-|DATE|날짜
날짜/시간형|TIME|-|TIME|시간
날짜/시간형|TIMESTAMP / TIMESTMP|-|TIMESTAMP|날짜 및 시간
이진형|BINARY / VARBINARY / VARBIN|-|RAW(LENGTH)|바이너리 데이터
LOB형(대용량)|LONG VARCHAR|-|CLOB|대용량 문자 객체
LOB형(대용량)|LONG VARG / LONG VARGRAPHIC|-|NCLOB|대용량 다국어 문자 객체
LOB형(대용량)|CLOB|-|CLOB|대용량 문자 객체
LOB형(대용량)|BLOB|-|BLOB|대용량 이진 객체
LOB형(대용량)|DBCLOB|-|CLOB|더블바이트 문자 객체
특수형|XML|-|XMLTYPE|XML 데이터
특수형|ROWID|-|VARCHAR2(100)|행 식별자
특수형|DATALINK|-|VARCHAR2(255)|외부 파일 링크
사용자 정의형|DISTINCT|-|"""<user_defined_type>"""|사용자 정의 타입명을 소문자로 변환 후 큰따옴표로 묶음
기타|그 외 (ELSE)|위 조건에 해당 없음|원본 데이터 타입명 그대로 사용|공백 제거 후 적용




```sql
WITH table_a AS (
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'public' -- 필요시 스키마명 변경
      AND table_name = '첫번째_테이블명'
),
table_b AS (
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'public' -- 필요시 스키마명 변경
      AND table_name = '두번째_테이블명'
)
SELECT 
    COALESCE(a.column_name, b.column_name) AS column_name,
    a.data_type AS table_a_type,
    b.data_type AS table_b_type,
    CASE 
        WHEN a.column_name IS NULL THEN '테이블A에 컬럼 없음'
        WHEN b.column_name IS NULL THEN '테이블B에 컬럼 없음'
        WHEN a.data_type != b.data_type THEN '데이터 타입 불일치'
        ELSE '완벽 일치'
    END AS status
FROM table_a a
FULL OUTER JOIN table_b b 
    ON a.column_name = b.column_name
ORDER BY 
    CASE 
        WHEN a.column_name IS NULL OR b.column_name IS NULL OR a.data_type != b.data_type THEN 1 
        ELSE 2 
    END, 
    column_name;
```



##
```txt
<?xml version="1.0" encoding="UTF-8"?>
<pipeline>
  <info>
    <pipeline_version/>
    <capture_transform_performance>N</capture_transform_performance>
    <transform_performance_capturing_delay>1000</transform_performance_capturing_delay>
    <transform_performance_capturing_size_limit>100</transform_performance_capturing_size_limit>
    <pipeline_type>Normal</pipeline_type>
    <pipeline_status>0</pipeline_status>
    <parameters/>
    <name>apply_constraints</name>
    <name_sync_with_filename>Y</name_sync_with_filename>
    <description/>
    <extended_description/>
    <created_user>-</created_user>
    <modified_user>-</modified_user>
    <created_date>2026/08/21 00:00:00.000</created_date>
    <modified_date>2026/08/21 00:00:00.000</modified_date>
  </info>
  <transform>
    <type>RowGenerator</type>
    <name>One Row</name>
    <fields>
      <field>
        <name>dummy</name>
        <type>Integer</type>
        <length>-1</length>
        <precision>-1</precision>
        <nullif>1</nullif>
        <set_empty_string>N</set_empty_string>
      </field>
    </fields>
    <limit>1</limit>
    <never_ending>N</never_ending>
    <start_at_row>0</start_at_row>
    <interval_in_ms>1000</interval_in_ms>
    <row_time_field/>
    <last_time_field/>
    <distribute>Y</distribute>
    <copies>1</copies>
    <GUI>
      <xloc>48</xloc>
      <yloc>48</yloc>
    </GUI>
    <partitioning>
      <method>none</method>
      <schema_name/>
    </partitioning>
    <attributes/>
  </transform>
  <transform>
    <name>Apply Constraints</name>
    <type>UserDefinedJavaClass</type>
    <description/>
    <distribute>Y</distribute>
    <custom_distribution/>
    <copies>1</copies>
    <partitioning>
      <method>none</method>
      <schema_name/>
    </partitioning>
    <definitions>
      <definition>
        <class_type>TRANSFORM_CLASS</class_type>
        <class_name>Processor</class_name>
        <class_source>
private String q(String identifier) {
  return "\"" + identifier.toLowerCase() + "\"";
}

private String qq(String schema, String name) {
  return "\"" + schema.toLowerCase() + "\".\"" + name.toLowerCase() + "\"";
}

// PRIMARY KEY / UNIQUE constraints and their columns, in declaration order.
private String buildPrimaryKeyQuery(String schema, String table) {
  StringBuilder sql = new StringBuilder();
  sql.append("SELECT C.CONSTRAINT_NAME, C.CONSTRAINT_TYPE, K.COLUMN_NAME, K.ORDINAL_POSITION ");
  sql.append("FROM QSYS2.SYSCST C ");
  sql.append("JOIN QSYS2.SYSKEYCST K ON C.CONSTRAINT_SCHEMA = K.CONSTRAINT_SCHEMA AND C.CONSTRAINT_NAME = K.CONSTRAINT_NAME ");
  sql.append("WHERE C.TABLE_SCHEMA = '").append(schema).append("' AND C.TABLE_NAME = '").append(table).append("' ");
  sql.append("AND C.CONSTRAINT_TYPE IN ('PRIMARY KEY', 'UNIQUE') ");
  sql.append("ORDER BY C.CONSTRAINT_NAME, K.ORDINAL_POSITION");
  return sql.toString();
}

// FOREIGN KEY constraints: local column(s), the referenced table/
// column(s) in matching key order, and the ON UPDATE/ON DELETE rules
// (DB2 for i reports these using the same keywords Postgres accepts:
// NO ACTION, CASCADE, RESTRICT, SET NULL, SET DEFAULT).
private String buildForeignKeyQuery(String schema, String table) {
  StringBuilder sql = new StringBuilder();
  sql.append("SELECT FC.CONSTRAINT_NAME AS FK_NAME, FK.COLUMN_NAME AS LOCAL_COLUMN, FK.ORDINAL_POSITION AS COL_POS, ");
  sql.append("RC.TABLE_SCHEMA AS REF_SCHEMA, RC.TABLE_NAME AS REF_TABLE, RK.COLUMN_NAME AS REF_COLUMN, ");
  sql.append("R.UPDATE_RULE, R.DELETE_RULE ");
  sql.append("FROM QSYS2.SYSCST FC ");
  sql.append("JOIN QSYS2.SYSREFCST R ON FC.CONSTRAINT_SCHEMA = R.CONSTRAINT_SCHEMA AND FC.CONSTRAINT_NAME = R.CONSTRAINT_NAME ");
  sql.append("JOIN QSYS2.SYSKEYCST FK ON FC.CONSTRAINT_SCHEMA = FK.CONSTRAINT_SCHEMA AND FC.CONSTRAINT_NAME = FK.CONSTRAINT_NAME ");
  sql.append("JOIN QSYS2.SYSCST RC ON R.UNIQUE_CONSTRAINT_SCHEMA = RC.CONSTRAINT_SCHEMA AND R.UNIQUE_CONSTRAINT_NAME = RC.CONSTRAINT_NAME ");
  sql.append("JOIN QSYS2.SYSKEYCST RK ON RC.CONSTRAINT_SCHEMA = RK.CONSTRAINT_SCHEMA AND RC.CONSTRAINT_NAME = RK.CONSTRAINT_NAME AND FK.ORDINAL_POSITION = RK.ORDINAL_POSITION ");
  sql.append("WHERE FC.TABLE_SCHEMA = '").append(schema).append("' AND FC.TABLE_NAME = '").append(table).append("' ");
  sql.append("AND FC.CONSTRAINT_TYPE = 'FOREIGN KEY' ");
  sql.append("ORDER BY FC.CONSTRAINT_NAME, FK.ORDINAL_POSITION");
  return sql.toString();
}

// CHECK constraint expression text, copied as-is into the generated
// Postgres DDL. Only queried when apply_check_constraints is true -
// CHECK expressions are raw source SQL text and may not translate
// cleanly, so a failure here is recorded per constraint rather than
// aborting the run (see execConstraintDdl).
private String buildCheckQuery(String schema, String table) {
  StringBuilder sql = new StringBuilder();
  sql.append("SELECT C.CONSTRAINT_NAME, CK.CHECK_CLAUSE ");
  sql.append("FROM QSYS2.SYSCST C ");
  sql.append("JOIN QSYS2.SYSCHKCST CK ON C.CONSTRAINT_SCHEMA = CK.CONSTRAINT_SCHEMA AND C.CONSTRAINT_NAME = CK.CONSTRAINT_NAME ");
  sql.append("WHERE C.TABLE_SCHEMA = '").append(schema).append("' AND C.TABLE_NAME = '").append(table).append("' ");
  sql.append("AND C.CONSTRAINT_TYPE = 'CHECK'");
  return sql.toString();
}

public boolean processRow() throws HopException
{
  Object[] r = getRow();
  if (r == null) {
    setOutputDone();
    return false;
  }

  if (first) {
    first = false;

    String configPath = getVariable("PROJECT_HOME") + "/config.yaml";
    java.util.Map root = null;

    try {
      java.io.FileInputStream fis = new java.io.FileInputStream(configPath);
      org.yaml.snakeyaml.Yaml yaml = new org.yaml.snakeyaml.Yaml();
      Object loaded = yaml.load(fis);
      fis.close();
      if (loaded instanceof java.util.Map) {
        root = (java.util.Map) loaded;
      }
    } catch (Exception e) {
      logError("Could not read config.yaml: " + e.getMessage());
    }

    if (root == null) {
      logError("Could not load config.yaml - aborting constraint application");
      setOutputDone();
      return false;
    }

    java.util.Map general = (java.util.Map) root.get("general");
    java.util.Map migration = (java.util.Map) root.get("migration");

    boolean applyConstraints = Boolean.parseBoolean(String.valueOf(migration.get("apply_constraints")));
    boolean applyCheckConstraints = Boolean.parseBoolean(String.valueOf(migration.get("apply_check_constraints")));

    if (!applyConstraints &amp;&amp; !applyCheckConstraints) {
      logBasic("apply_constraints and apply_check_constraints are both false - skipping constraint stage");
      setOutputDone();
      return false;
    }

    // table_select/table_exclude must be honored here too, the same way
    // gather_table_info.hpl/migrate_table.hpl honor them at load time -
    // a table left out of the load never gets created in the target
    // schema, so attempting its constraints here would just fail
    // per-constraint (target table not found) instead of being skipped.
    java.util.Set tableSelect = new java.util.HashSet();
    java.util.Set tableExclude = new java.util.HashSet();
    Object selObj = migration.get("table_select");
    if (selObj instanceof java.util.List) {
      java.util.Iterator selIt = ((java.util.List) selObj).iterator();
      while (selIt.hasNext()) tableSelect.add(String.valueOf(selIt.next()).trim());
    }
    Object exclObj = migration.get("table_exclude");
    if (exclObj instanceof java.util.List) {
      java.util.Iterator exclIt = ((java.util.List) exclObj).iterator();
      while (exclIt.hasNext()) tableExclude.add(String.valueOf(exclIt.next()).trim());
    }
    boolean tableSelectConfigured = !tableSelect.isEmpty();

    java.util.Map asisCfg = (java.util.Map) general.get("ASIS");
    String activeSource = getVariable("ACTIVE_SOURCE");
    java.util.Map sourceCfg = (java.util.Map) asisCfg.get(activeSource);
    String srcConnName = String.valueOf(sourceCfg.get("connection"));
    String srcSchema = String.valueOf(sourceCfg.get("schema"));

    java.util.Map tobeCfg = (java.util.Map) general.get("TOBE");
    String tgtConnName = String.valueOf(tobeCfg.get("connection"));
    String tgtSchema = String.valueOf(tobeCfg.get("schema"));

    boolean resumeFromCheckpoint = Boolean.parseBoolean(getVariable("RESUME_FROM_CHECKPOINT", "false"));
    String statusDbPath = getVariable("STATUS_DB_PATH");
    org.apache.hop.core.database.Database statusDb = null;
    java.sql.Connection statusConn = null;
    if (resumeFromCheckpoint &amp;&amp; statusDbPath != null &amp;&amp; statusDbPath.length() &gt; 0) {
      try {
        org.apache.hop.core.database.DatabaseMeta statusDbMeta =
          (org.apache.hop.core.database.DatabaseMeta) getParent().getMetadataProvider()
            .getSerializer(org.apache.hop.core.database.DatabaseMeta.class)
            .load("STATUS_DB");
        statusDb = new org.apache.hop.core.database.Database(getParent(), getParent(), statusDbMeta);
        statusDb.connect();
        statusConn = statusDb.getConnection();
        java.sql.Statement pragma = statusConn.createStatement();
        pragma.execute("PRAGMA busy_timeout=30000");
        pragma.close();
      } catch (Exception e) {
        logError("Could not open checkpoint database " + statusDbPath + ": " + e.getMessage() + " - proceeding without checkpoint tracking");
        statusDb = null;
        statusConn = null;
      }
    }

    try {
      org.apache.hop.core.database.DatabaseMeta srcDbMeta =
        (org.apache.hop.core.database.DatabaseMeta) getParent().getMetadataProvider()
          .getSerializer(org.apache.hop.core.database.DatabaseMeta.class)
          .load(srcConnName);
      org.apache.hop.core.database.Database srcDb =
        new org.apache.hop.core.database.Database(getParent(), getParent(), srcDbMeta);
      srcDb.connect();

      org.apache.hop.core.database.DatabaseMeta tgtDbMeta =
        (org.apache.hop.core.database.DatabaseMeta) getParent().getMetadataProvider()
          .getSerializer(org.apache.hop.core.database.DatabaseMeta.class)
          .load(tgtConnName);
      org.apache.hop.core.database.Database tgtDb =
        new org.apache.hop.core.database.Database(getParent(), getParent(), tgtDbMeta);
      tgtDb.connect();

      try {
        String tableListSql = "SELECT TABLE_NAME FROM QSYS2.SYSTABLES WHERE TABLE_SCHEMA = '" + srcSchema + "' AND TABLE_TYPE IN ('T', 'P')";
        java.util.List tableRows = srcDb.getRows(tableListSql, 0);

        // Pending tables only (checkpoint skips carried over unchanged).
        // A foreign key can reference a table anywhere in this list -
        // including one that comes later, or one that in turn
        // references it back (e.g. an employee/department pair with a
        // manager FK each way) - so PK/UNIQUE must be created for every
        // pending table in a first pass, fully, before any FOREIGN KEY
        // is attempted in a second pass. Combining PK+FK per table in a
        // single pass (the previous approach) fails with "there is no
        // unique constraint matching given keys" whenever a referenced
        // table's own PK/UNIQUE pass hasn't run yet.
        java.util.List pendingTables = new java.util.ArrayList();
        java.util.Map tableHadError = new java.util.LinkedHashMap();
        java.util.Map tableErrorMsg = new java.util.HashMap();

        for (int t = 0; t &lt; tableRows.size(); t++) {
          Object[] tr = (Object[]) tableRows.get(t);
          String tableName = String.valueOf(tr[0]).trim();

          if (tableSelectConfigured &amp;&amp; !tableSelect.contains(tableName)) {
            continue;
          }
          if (tableExclude.contains(tableName)) {
            continue;
          }

          if (statusConn != null &amp;&amp; isPhaseSuccessful(statusConn, tableName, "constraints")) {
            logBasic("Skipping " + tableName + " - constraints already applied successfully (checkpoint)");
            continue;
          }

          pendingTables.add(tableName);
          tableHadError.put(tableName, Boolean.FALSE);
        }

        if (applyConstraints) {
          // Pass 1: PRIMARY KEY / UNIQUE for every pending table.
          for (int t = 0; t &lt; pendingTables.size(); t++) {
            String tableName = (String) pendingTables.get(t);
            try {
              String pkSql = buildPrimaryKeyQuery(srcSchema, tableName);
              java.util.List pkRows = srcDb.getRows(pkSql, 0);

              java.util.Map grouped = new java.util.LinkedHashMap();
              java.util.Map typeByName = new java.util.HashMap();
              for (int i = 0; i &lt; pkRows.size(); i++) {
                Object[] pr = (Object[]) pkRows.get(i);
                String cname = String.valueOf(pr[0]).trim();
                String ctype = String.valueOf(pr[1]).trim();
                String colName = String.valueOf(pr[2]).trim();
                java.util.List cols = (java.util.List) grouped.get(cname);
                if (cols == null) {
                  cols = new java.util.ArrayList();
                  grouped.put(cname, cols);
                  typeByName.put(cname, ctype);
                }
                cols.add(colName);
              }

              java.util.Iterator gIt = grouped.keySet().iterator();
              while (gIt.hasNext()) {
                String cname = (String) gIt.next();
                java.util.List cols = (java.util.List) grouped.get(cname);
                String ctype = (String) typeByName.get(cname);
                String pgClause = "PRIMARY KEY".equals(ctype) ? "PRIMARY KEY" : "UNIQUE";

                StringBuffer colList = new StringBuffer();
                for (int i = 0; i &lt; cols.size(); i++) {
                  if (i &gt; 0) {
                    colList.append(", ");
                  }
                  colList.append(q((String) cols.get(i)));
                }

                String ddl = "ALTER TABLE " + qq(tgtSchema, tableName) + " ADD CONSTRAINT " + q(cname) + " " + pgClause + " (" + colList + ")";
                if (!execConstraintDdl(tgtDb, ddl, tableName, cname)) {
                  tableHadError.put(tableName, Boolean.TRUE);
                  tableErrorMsg.put(tableName, "PK/UNIQUE constraint " + cname + " failed");
                }
              }
            } catch (Exception e) {
              logError("Could not query PK/UNIQUE constraints for " + tableName + ": " + e.getMessage());
              tableHadError.put(tableName, Boolean.TRUE);
              tableErrorMsg.put(tableName, "PK/UNIQUE query failed: " + e.getMessage());
            }
          }

          // Pass 2: FOREIGN KEY for every pending table, now that every
          // pending table's own PK/UNIQUE constraints already exist.
          for (int t = 0; t &lt; pendingTables.size(); t++) {
            String tableName = (String) pendingTables.get(t);
            try {
              String fkSql = buildForeignKeyQuery(srcSchema, tableName);
              java.util.List fkRows = srcDb.getRows(fkSql, 0);

              java.util.Map groupedLocal = new java.util.LinkedHashMap();
              java.util.Map groupedRef = new java.util.LinkedHashMap();
              java.util.Map refTableByName = new java.util.HashMap();
              java.util.Map rulesByName = new java.util.HashMap();

              for (int i = 0; i &lt; fkRows.size(); i++) {
                Object[] fr = (Object[]) fkRows.get(i);
                String cname = String.valueOf(fr[0]).trim();
                String localCol = String.valueOf(fr[1]).trim();
                String refTable = String.valueOf(fr[4]).trim();
                String refCol = String.valueOf(fr[5]).trim();
                String updRule = String.valueOf(fr[6]).trim();
                String delRule = String.valueOf(fr[7]).trim();

                java.util.List lcols = (java.util.List) groupedLocal.get(cname);
                if (lcols == null) {
                  lcols = new java.util.ArrayList();
                  groupedLocal.put(cname, lcols);
                  groupedRef.put(cname, new java.util.ArrayList());
                  // The referenced table lives in the same target schema as
                  // every other migrated table, not the source schema
                  // reported by the catalog (fr[3]).
                  refTableByName.put(cname, qq(tgtSchema, refTable));
                  rulesByName.put(cname, new String[] { updRule, delRule });
                }
                lcols.add(localCol);
                ((java.util.List) groupedRef.get(cname)).add(refCol);
              }

              java.util.Iterator fIt = groupedLocal.keySet().iterator();
              while (fIt.hasNext()) {
                String cname = (String) fIt.next();
                java.util.List lcols = (java.util.List) groupedLocal.get(cname);
                java.util.List rcols = (java.util.List) groupedRef.get(cname);
                String refTableFull = (String) refTableByName.get(cname);
                String[] rules = (String[]) rulesByName.get(cname);

                StringBuffer lcolList = new StringBuffer();
                StringBuffer rcolList = new StringBuffer();
                for (int i = 0; i &lt; lcols.size(); i++) {
                  if (i &gt; 0) {
                    lcolList.append(", ");
                    rcolList.append(", ");
                  }
                  lcolList.append(q((String) lcols.get(i)));
                  rcolList.append(q((String) rcols.get(i)));
                }

                String ddl = "ALTER TABLE " + qq(tgtSchema, tableName) + " ADD CONSTRAINT " + q(cname)
                  + " FOREIGN KEY (" + lcolList + ") REFERENCES " + refTableFull + " (" + rcolList + ")"
                  + " ON UPDATE " + rules[0] + " ON DELETE " + rules[1];
                if (!execConstraintDdl(tgtDb, ddl, tableName, cname)) {
                  tableHadError.put(tableName, Boolean.TRUE);
                  tableErrorMsg.put(tableName, "FK constraint " + cname + " failed");
                }
              }
            } catch (Exception e) {
              logError("Could not query FK constraints for " + tableName + ": " + e.getMessage());
              tableHadError.put(tableName, Boolean.TRUE);
              tableErrorMsg.put(tableName, "FK query failed: " + e.getMessage());
            }
          }
        }

        if (applyCheckConstraints) {
          for (int t = 0; t &lt; pendingTables.size(); t++) {
            String tableName = (String) pendingTables.get(t);
            try {
              String checkSql = buildCheckQuery(srcSchema, tableName);
              java.util.List checkRows = srcDb.getRows(checkSql, 0);
              for (int i = 0; i &lt; checkRows.size(); i++) {
                Object[] cr = (Object[]) checkRows.get(i);
                String cname = String.valueOf(cr[0]).trim();
                String clause = String.valueOf(cr[1]).trim();
                String ddl = "ALTER TABLE " + qq(tgtSchema, tableName) + " ADD CONSTRAINT " + q(cname) + " CHECK (" + clause + ")";
                if (!execConstraintDdl(tgtDb, ddl, tableName, cname)) {
                  tableHadError.put(tableName, Boolean.TRUE);
                  tableErrorMsg.put(tableName, "CHECK constraint " + cname + " failed");
                }
              }
            } catch (Exception e) {
              logError("Could not query CHECK constraints for " + tableName + ": " + e.getMessage());
              tableHadError.put(tableName, Boolean.TRUE);
              tableErrorMsg.put(tableName, "CHECK query failed: " + e.getMessage());
            }
          }
        }

        if (statusConn != null) {
          for (int t = 0; t &lt; pendingTables.size(); t++) {
            String tableName = (String) pendingTables.get(t);
            boolean hadError = Boolean.TRUE.equals(tableHadError.get(tableName));
            recordPhaseStatus(statusConn, tableName, "constraints", hadError ? "FAILED" : "SUCCESS", (String) tableErrorMsg.get(tableName));
          }
        }
      } finally {
        srcDb.disconnect();
        tgtDb.disconnect();
        if (statusDb != null) {
          statusDb.disconnect();
        }
      }
    } catch (Exception e) {
      logError("Constraint application failed: " + e.getMessage());
      setErrors(1);
    }
  }

  setOutputDone();
  return false;
}

private boolean execConstraintDdl(org.apache.hop.core.database.Database tgtDb, String ddl, String tableName, String constraintName) {
  try {
    tgtDb.execStatement(ddl);
    logBasic("Constraint " + constraintName + " created on " + tableName);
    return true;
  } catch (Exception e) {
    String msg = e.getMessage() == null ? "" : e.getMessage();
    if (msg.indexOf("already exists") &gt;= 0 || msg.indexOf("multiple primary keys") &gt;= 0) {
      logBasic("Constraint " + constraintName + " on " + tableName + " already exists - skipping");
      return true;
    } else {
      logError("Failed to create constraint " + constraintName + " on " + tableName + ": " + msg + " | DDL: " + ddl);
      return false;
    }
  }
}

private boolean isPhaseSuccessful(java.sql.Connection conn, String tableName, String phase) {
  try {
    java.sql.PreparedStatement ps = conn.prepareStatement(
      "SELECT status FROM migration_status WHERE table_name=? AND partition_name='' AND phase=?");
    ps.setString(1, tableName);
    ps.setString(2, phase);
    java.sql.ResultSet rs = ps.executeQuery();
    boolean success = false;
    if (rs.next()) {
      success = "SUCCESS".equals(rs.getString(1));
    }
    rs.close();
    ps.close();
    return success;
  } catch (Exception e) {
    logError("Checkpoint lookup failed for " + tableName + "/" + phase + ": " + e.getMessage());
    return false;
  }
}

private void recordPhaseStatus(java.sql.Connection conn, String tableName, String phase, String status, String errorMessage) {
  try {
    java.sql.PreparedStatement ps = conn.prepareStatement(
      "INSERT INTO migration_status (table_name, partition_name, phase, status, attempted_at, error_message) "
      + "VALUES (?, '', ?, ?, ?, ?) "
      + "ON CONFLICT(table_name, partition_name, phase) DO UPDATE SET status=excluded.status, attempted_at=excluded.attempted_at, error_message=excluded.error_message");
    ps.setString(1, tableName);
    ps.setString(2, phase);
    ps.setString(3, status);
    ps.setString(4, new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new java.util.Date()));
    ps.setString(5, errorMessage);
    ps.executeUpdate();
    ps.close();
  } catch (Exception e) {
    logError("Could not record checkpoint status for " + tableName + "/" + phase + ": " + e.getMessage());
  }
}
</class_source>
      </definition>
    </definitions>
    <fields/>
    <clear_result_fields>N</clear_result_fields>
    <info_transforms/>
    <target_transforms/>
    <usage_parameters/>
    <attributes/>
    <GUI>
      <xloc>192</xloc>
      <yloc>48</yloc>
    </GUI>
  </transform>
  <order>
    <hop>
      <from>One Row</from>
      <to>Apply Constraints</to>
      <enabled>Y</enabled>
    </hop>
  </order>
  <notepads/>
  <attributes/>
  <transform_error_handling/>
</pipeline>
```
