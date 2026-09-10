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
