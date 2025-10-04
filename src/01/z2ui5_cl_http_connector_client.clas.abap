CLASS z2ui5_cl_http_connector_client DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_http_connector_client IMPLEMENTATION.


  METHOD if_http_service_extension~handle_request.

*    z2ui5_cl_http_handler=>run( req = request res = response ).

   " Create http client

    DATA:
  lo_client   TYPE REF TO if_web_http_client.
*  lo_client_proxy  TYPE REF TO /iwbep/if_cp_client_proxy.

  DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                             comm_scenario  = 'TRAVEL_BASIC'
                                             comm_system_id = 'TRAVEL_BASIC'
                                             service_id     = 'OutboundCommunication' ).
  lo_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

*lo_client->get_http_request( )->set_header_field( i_name  = 'Swh-API-Key'
*                                                  i_value = c_api_key ).


DATA(lo_response) = lo_client->execute( i_method = if_web_http_client=>get ).


DATA(ld_content_type) = lo_response->get_content_type( ).
DATA(ls_status) = lo_response->get_status( ).
DATA(ld_text) = lo_response->get_text( ).

  ENDMETHOD.

ENDCLASS.



