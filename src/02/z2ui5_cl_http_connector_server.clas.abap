CLASS z2ui5_cl_http_connector_server DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_http_connector_server IMPLEMENTATION.


  METHOD if_http_service_extension~handle_request.

    z2ui5_cl_http_handler=>run( req = request res = response ).

  ENDMETHOD.

ENDCLASS.



