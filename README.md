# dbtvault-bigquery-demo
This repository is a demo to use dbtvault levaraging dbt tutorial by using BigQuery.

The official document of dbtvault has own [tutorials](https://dbtvault.readthedocs.io/en/latest/tutorial/tut_getting_started/), however the execution requires Snowflake usage.  
On the other hand, dbt has the [getting started page](https://docs.getdbt.com/tutorial/learning-more/getting-started-dbt-core) based on BigQuery that uses dbt's public dataset in `dbt-tutorial` project.

This demo is for people who more familiar with BigQuery, and try dbtvault as the same dataset as dbt tutorial.

# Getting Started dbtvault

## Prerequisite
To try dbtvault, it is good idea to go through [dbt tutorial](https://docs.getdbt.com/tutorial/learning-more/getting-started-dbt-core) fist because BigQuery connectivity and data will be all set after completing the tutorial.

If you are new to dbt itself, good to go through [official docs](https://docs.getdbt.com/docs/introduction) as well.

## Prepare BigQuery Access
BigQuery accessibility is requied before running this demo.

1. Create a Dataset in BigQuery
2. Create a Service Account which has BigQuery write access
   - If which permission is not clear, give BigQuery Admin in your test project.
3. Download JSON key of Service Account

## Set up dbt profile
A [dbt profile](https://docs.getdbt.com/dbt-cli/configure-your-profile) should be set up to connect BigQuery from dbt.

The profile will be created when a new project is created via `dbt init` command. If you would like try dbtvault with just cloning this repository, add following config to your profile in `~/.dbt/profiles.yml`

```yaml
dbtvault-bigquery-demo:
  outputs:
    dev:
      dataset: YOUR_DATASET
      job_execution_timeout_seconds: 300
      job_retries: 1
      keyfile: PATH_TO_YOUR_SA_KEY
      location: US
      method: service-account
      priority: interactive
      project: GCP_PROJECT_ID
      threads: 1
      type: bigquery
  target: dev
```

You should replace following.

1. YOUR_DATASET
    - Your dataset name
2. PATH_TO_YOUR_SA_KEY
    - Path to your SA's JSON key
3. GCP_PROJECT_ID
    - Your GCP project id

Once profile is set up, test the connectivity with BigQuery by following command.
```shell
dbt debug
```

Now we are ready to play with dbtvault in BigQuery.

## Set up dbtvault
You can follow [docs](https://dbtvault.readthedocs.io/en/latest/) to get familiar with dbtvault. Although the tutorial is only executable in Snowflake as of May 2022, the document is good to use to learn basic syntax and usage of dbtvault.

### 1. Install dbtvault
To use dbtvault in dbt project, add `packages.yml` with follwoing contents and run `dbt deps`. Check the latest version in [here](https://hub.getdbt.com/datavault-uk/dbtvault/latest/)

```yaml
packages:
  - package: Datavault-UK/dbtvault
    version: 0.8.3
```

### 2. Set up raw data datasource
After completing dbt tutorial, `models` dir should have stg_*.sql files. 
We use the public data of dbt-tutorial project as datasource in this demo, and make raw staging layer based on the data. Rename stg_*.sql as raw_stg_*.sql and move to `models/raw_stage` dir.

Files modified:
- models/raw_stage/raw_stg_customers.sql
- models/raw_stage/raw_stg_orders.sql

Then, add following setting in the model section of dbt_project.yml
```yaml
models:
  dbtvault-bigquery-demo:
    raw_stage:
        tags:
            - 'raw'
        +materialized: view
```

### 3. Set up hash staging layer
dbtvault uses [hash staging layer](https://dbtvault.readthedocs.io/en/latest/tutorial/tut_staging/) as intermediate layer to prepare constructing vault. The hash staging layer has original data + drived data such as hash key and Data Vault specific fields like DataSource, LoadTimeDate, and e.t.c..

Create stage dir under models and create stg_*.sql.

Exmaple: stg_customer.sql
```sql
{%- set yaml_metadata -%}
source_model: 'raw_stg_customers'
derived_columns:
  RECORD_SOURCE: '!customers'
  EFFECTIVE_FROM: CURRENT_DATE()
  LOAD_DATE: CURRENT_DATE()
hashed_columns:
  CUSTOMER_PK:
    - 'customer_id'
  CUSTOMER_HASHDIFF:
    is_hashdiff: true
    columns:
      - 'customer_id'
      - 'first_name'
      - 'last_name'
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{% set source_model = metadata_dict['source_model'] %}

{% set derived_columns = metadata_dict['derived_columns'] %}

{% set hashed_columns = metadata_dict['hashed_columns'] %}

{{ dbtvault.stage(include_source_columns=true,
                  source_model=source_model,
                  derived_columns=derived_columns,
                  hashed_columns=hashed_columns,
                  ranked_columns=none) }}
```

### 4. Set up vault
In this demo, we create hubs, links, and satelites as vault.

Create `vault` dir under `models` and put related contents.

#### 4.1 Hubs
Hubs are one of the core building blocks in Data Vault. Create `hubs` dir under `models/vault`. Put SQLs for hubs.

Example: h_customer.sql
```sql
{%- set source_model = ["stg_customer"] -%}
{%- set src_pk = "CUSTOMER_PK" -%}
{%- set src_nk = "CUSTOMER_ID" -%}
{%- set src_ldts = "LOAD_DATE" -%}
{%- set src_source = "RECORD_SOURCE" -%}

{{ dbtvault.hub(src_pk=src_pk, src_nk=src_nk, src_ldts=src_ldts,
                src_source=src_source, source_model=source_model) }}
```

#### 4.2 Links
Links are association of business objects like Hubs or Satelites. Create `link` dir under `models/vault`. Put SQLs for links.

Example: l_customer_order.sql
```sql
{%- set source_model = "stg_order" -%}
{%- set src_pk = "LINK_ORDER_CUSTOMER_PK" -%}
{%- set src_fk = ["ORDER_PK", "CUSTOMER_PK"] -%}
{%- set src_ldts = "LOAD_DATE" -%}
{%- set src_source = "RECORD_SOURCE" -%}

{{ dbtvault.link(src_pk=src_pk, src_fk=src_fk, src_ldts=src_ldts,
                 src_source=src_source, source_model=source_model) }}
```
In this example, data of the link is extracted from stg_order.sql.

#### 4.3 Satellites
Satellites are detailed payload data of parent hub or link. Create `satellites` dir under `models/vault`. Put SQLs for satellites.

Example: s_customer.sql
```sql
{%- set source_model = "stg_customer" -%}
{%- set src_pk = "CUSTOMER_PK" -%}
{%- set src_hashdiff = "CUSTOMER_HASHDIFF" -%}
{%- set src_payload = ["CUSTOMER_ID","FIRST_NAME", "LAST_NAME"] -%}
{%- set src_eff = "EFFECTIVE_FROM" -%}
{%- set src_ldts = "LOAD_DATE" -%}
{%- set src_source = "RECORD_SOURCE" -%}

{{ dbtvault.sat(src_pk=src_pk, src_hashdiff=src_hashdiff,
                src_payload=src_payload, src_eff=src_eff,
                src_ldts=src_ldts, src_source=src_source,
                source_model=source_model) }}
```


### 5. Run
After adding vault related setting, update models section of project yaml like below. In this demo, vault layer is persisted as table so that easier to check the contents in preview in the BigQuery. It can be view based on preference.
```yaml
models:
  dbtvault-bigquery-demo:
    # Config indicated by + and applies to all files under models/example/
    raw_stage:
      +materialized: view
    stage:
      +materialized: view
    vault:
      +materialized: table
```

Finally, run `dbt run` and check BigQuery after completion!

# Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Learn more about dbtvault [in the docs](https://dbtvault.readthedocs.io/en/latest/)
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
