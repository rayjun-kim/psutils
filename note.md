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
