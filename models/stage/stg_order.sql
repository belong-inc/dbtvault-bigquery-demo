{%- set yaml_metadata -%}
source_model: 'raw_stg_orders'
derived_columns:
  ORDER_KEY: 'order_id'
  RECORD_SOURCE: '!order'
  EFFECTIVE_FROM: 'order_date'
  LOAD_DATE: CURRENT_DATE()
hashed_columns:
  ORDER_PK:
    - 'order_id'
  CUSTOMER_PK:
    - 'customer_id'
  LINK_ORDER_CUSTOMER_PK:
    - 'order_id'
    - 'customer_id'
  ORDER_HASHDIFF:
    is_hashdiff: true
    columns:
      - 'customer_id'
      - 'order_id'
      - 'order_date'
      - 'status'
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