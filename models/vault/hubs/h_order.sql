{%- set source_model = "stg_order" -%}
{%- set src_pk = "ORDER_PK" -%}
{%- set src_nk = "ORDER_ID" -%}
{%- set src_ldts = "LOAD_DATE" -%}
{%- set src_source = "RECORD_SOURCE" -%}

{{ dbtvault.hub(src_pk=src_pk, src_nk=src_nk, src_ldts=src_ldts,
                src_source=src_source, source_model=source_model) }}