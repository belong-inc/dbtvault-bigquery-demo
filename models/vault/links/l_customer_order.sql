{%- set source_model = "stg_order" -%}
{%- set src_pk = "LINK_ORDER_CUSTOMER_PK" -%}
{%- set src_fk = ["ORDER_PK", "CUSTOMER_PK"] -%}
{%- set src_ldts = "LOAD_DATE" -%}
{%- set src_source = "RECORD_SOURCE" -%}

{{ dbtvault.link(src_pk=src_pk, src_fk=src_fk, src_ldts=src_ldts,
                 src_source=src_source, source_model=source_model) }}