# http-connector

Remotely Call abap2UI5 Apps via HTTP


```abap
  METHOD if_http_service_extension~handle_request.


    "1. read request
    DATA(lo_http_request) = z2ui5_cl_util_http=>factory_cloud( req = request res = response ).

    DATA(lv_method) = lo_http_request->get_method( ).
    DATA(lv_cdata) = lo_http_request->get_cdata( ).
*    lo_http->get_header_fields( ).



    "2. create new request
    DATA lo_client   TYPE REF TO if_web_http_client.
*  lo_client_proxy  TYPE REF TO /iwbep/if_cp_client_proxy.

    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
      comm_scenario  = 'TRAVEL_BASIC'
      comm_system_id = 'TRAVEL_BASIC'
      service_id     = 'OutboundCommunication' ).
    lo_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

    DATA(lo_request) = lo_client->get_http_request( ).
    lo_request->set_text( lv_cdata ).



    "3. send new request
    CASE lv_method.
      WHEN `GET`.
        DATA(lo_response) = lo_client->execute( i_method = if_web_http_client=>get ).
      WHEN `POST`.
        lo_response = lo_client->execute( i_method = if_web_http_client=>post ).
    ENDCASE.



    "4. create response
    "todo: add response handling to util
*    DATA(lo_http_response) = z2ui5_cl_util_http=>factory_cloud_server( lo_response ).

    DATA(ld_content_type) = lo_response->get_content_type( ).
    DATA(ls_status) = lo_response->get_status( ).
    DATA(lv_text) = lo_response->get_text( ).

    response->set_text( lv_text ).

  ENDMETHOD.
```
